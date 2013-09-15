package Hadashot::Backend;
use v5.016;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::JSON;
use Mojo::Util qw(decode slurp);
use List::Util qw(shuffle);
use Mojo::IOLoop;
use Mango;
use Mango::BSON qw(bson_time);
use HTTP::Date;

has conf => sub { {} };
has dbh =>sub { Mango->new($_[0]->conf->{'db_connect'}) };
has db => sub { $_[0]->dbh->db($_[0]->conf->{'db_name'}); };
has json => sub { Mojo::JSON->new(); };
has dom => sub { Mojo::DOM->new(); };
has ua => sub { Mojo::UserAgent->new(); };
has feeds => sub { $_[0]->db()->collection($_[0]->conf->{'db_feeds'}) };
has items => sub { $_[0]->db()->collection($_[0]->conf->{'db_items'}) };
has log => sub { Mojo::Log->new() };

sub setup {
  my ($self) = @_;
  $self->items->ensure_index({published => -1});
  $self->items->ensure_index({origin => 1});
}

sub reset { # wanna drop all your data? cool.
	my ($self) = @_;
	$self->feeds->drop( sub {
		my ($col, $er) = @_;
		$self->log->info('dropped feeds');
		if ($er) {
			$self->log->error('Got error ' , $er);
		}
		$col->create();
  } );
	$self->items->drop( sub { $_[0]->create(); });
	$self->log->info('dropped all subs and items');
}

sub parse_opml {
  my ($self, $opml_file) = @_;
  my $opml_str  = decode 'UTF-8', (ref $opml_file) ? $opml_file->slurp : slurp $opml_file;
  my $d = Mojo::DOM->new($opml_str);
  my (%subscriptions, %categories);
  for my $item ($d->find(q{outline})->each) {
	my $node = $item->attr;
	if (!defined $node->{type} || $node->{type} ne 'rss') {
	  my $cat = $node->{title} || $node->{text};
	  $categories{$cat} = $item->children->pluck('attr', 'xmlUrl');
	}
	else { # file by RSS URL:
	  $subscriptions{ $node->{xmlUrl} } = $node;
	}
  }
  # assign categories
  for my $cat (keys %categories) {
	$self->log->info( "category $cat\n" );
	for my $rss ($categories{$cat}->each) {
		$subscriptions{$rss}{'categories'} ||= [];
		push @{$subscriptions{$rss}{'categories'}}, $cat;
	}
  }
  return (values %subscriptions);
}


sub get_direction {
  my ($self, $text ) = @_;
  #my $is_bidi = ($text =~ /\p{Hebrew}+/);
  return ($text =~ /\p{Bidi_Class:R}+/) ? 'rtl' : 'ltr';
}

sub fetch_subscriptions {
  my ($self, $check_all, $limit) = @_;
  my $ua = $self->ua;
  $ua->max_redirects(5)->connect_timeout(30);
  my $subs;
  if ($check_all) {
    $subs = $self->feeds->find()->all();
  }
  else {
    $subs = $self->feeds->find({ "active" => 1 })->all();
  }
  $subs = [ shuffle @$subs ];
  $subs = (defined $limit && $limit > 0 && $limit <= $#$subs) ?  @$subs[0..$limit] : $subs;
  my @all = @$subs;
  my $total = scalar @$subs;
  $self->log->info( "Will check $total feeds" );
  $self->process_feeds($subs, sub {
    my $self = shift;
    my $inactive = grep { ! $_->{active} } @all;
    my $active = grep { $_->{active} } @all; 
    $self->log->info( "Marked $active feeds as active and $inactive as inactive" );
  });
}

sub process_feeds {
  my ($self, $subs, $cb) = @_;
  state $delay = Mojo::IOLoop->delay(sub { $self->log->info((@$subs) ? "Ended before queue exhausted! " : "Done"); $self->$cb; });
  state $active = 0;
  my $max_concurrent = 8;
  while ( $active < $max_concurrent and my $sub = shift @$subs ) {
    my $url = $sub->{xmlUrl};
		my %not_modified_headers;
		my $last_modified = $sub->{last_modified};
		my $etag = $sub->{etag};
		$not_modified_headers{'If-Modified-Since'} = $last_modified if ($last_modified);
		$not_modified_headers{'If-None-Match'} = $etag if ($etag);
    $active++;
    my $end = $delay->begin(0);
    $self->ua->get($url => \%not_modified_headers => sub {
      $active--;
      $self->process_feed($sub, @_);
      $self->process_feeds($subs);
      $end->();
    });
  };
  $delay->wait unless Mojo::IOLoop->is_running;
}

sub process_feed {
  my ($self, $sub, $ua, $tx) = @_;
  my $url = $sub->{xmlUrl};
  if (my $res = $tx->success) {
    if ($tx->res->code == 200) {
      my $headers = $tx->res->headers;
      my ($last_modified, $etag) = ($headers->last_modified, $headers->etag);
      $self->log->debug( $url . " :-) " . $tx->res->code
        . " " . ($last_modified // '') . " " . ($etag // '') );
      if ($last_modified) {
        $sub->{last_modified} = $last_modified;
      }
      if ($etag) {
        $sub->{etag} = $etag;
      }
    	$self->parse_rss( 
				$res->content->asset,
				sub {
					my $item = pop; 
					$item->{'origin'} = $url; # save our source feed...
					$self->store_feed_item( $item );
				 }
			);
      $sub->{'active'} = 1;
    }
    else { $self->log->info( "$url :-( " . $tx->res->code ); };
  }
  else {
    my ($err, $code) = $tx->error;
    $self->log->info( $url . " :-( " . ( $code ? "$code response $err" : "connection error: $err" ) );
    $sub->{'active'} = 0;
  }
  $self->feeds->update({ _id => $sub->{'_id'} }, $sub);
}


sub store_feed_item {
				my ($self, $item) = @_;
				my ($link, $title, $content) = map { $item->{$_} } (qw(link title content));
				unless ($link)	{
								my $identifier = substr($title . $content . $item->{'_raw'}, 0, 40);
								$self->log->info( "No link for item $identifier");
				}
				else {
								$self->log->info( "Saving item with $link - $title" );
							  # convert dates to Mongodb BSON ?
								for (qw(published updated)) { 
									next unless ($item->{$_});
									$item->{$_} = bson_time $item->{$_} * 1000;
								};
								$self->items->update({ link => $link }, $item, { upsert => 1 });
				}
}

sub parse_json_collection {
	my ($self, $file) = @_;
	my $str = slurp $file;
	my $obj = $self->json->decode($str);
	my $items = delete $obj->{'items'};
	foreach my $item (@$items) {
		
	}
	my $props = $obj;
}

sub cleanup_reader_fields {
	my ($self, $item) = @_;
	
}

sub parse_rss {
	my ($self, $rss_file, $cb) = @_;
  my $rss_str  = decode 'UTF-8', (ref $rss_file) ? $rss_file->slurp : slurp $rss_file;
  my $d = Mojo::DOM->new($rss_str);
	my $items = $d->find('item');
	my $entries = $d->find('entry'); # Atom
  my $res = [];
	foreach my $item ($items->each, $entries->each) {
		push @$res, $self->parse_rss_item($item);
	}
	if ($cb) {
		foreach my $h (@$res) {
			$self->$cb($h);
		}
	}
	# get channel properties:
	#foreach my $k (qw(
  return $res;
}


sub parse_rss_item {
		my ($self, $item) = @_;
		my %h;
		foreach my $k (qw(title id summary guid content description content\:encoded pubDate published updated dc\:date)) {
			my $p = $item->at($k);
			if ($p) {
				$h{$k} = $p->text;
				if ($k eq 'pubDate' || $k eq 'published' || $k eq 'updated' || $k eq 'dc\:date') {
					$h{$k} = str2time($h{$k});
				}
			}
		}
    # let's handle links seperately, because ATOM loves these buggers:
    $item->find('link')->each( sub {
			my $l = shift;
			if ($l->attr('href')) {
				if (!$l->attr('rel') || $l->attr('rel') eq 'alternate') {
          $h{'link'} = $l->attr('href');
				}
			}
			else {
				if ($l->text =~ /\w+/) {
        	$h{'link'} = $l->text; # simple link
				}
				else { # we have an empty link element with no 'href'. :-(
					$h{'link'} = $1 if ($l->next->text =~ m/^(http\S+)/);
					$self->log->debug("extracted link from neighbour ... " . $h{'link'});
				}
       }
    });
    #
		# normalize fields:
		my %replace = ( 'content\:encoded' => 'content', 'pubDate' => 'published', 'dc\:date' => 'published', 'summary' => 'description', 'updated' => 'published', 'guid' => 'link' );
		while (my ($old, $new) = each %replace) {
		if ($h{$old} && ! $h{$new}) {
			$h{$new} = delete $h{$old};
		}
    }
    $h{"_raw"} = $item->to_xml;
		return \%h;
}


sub sanitize_item {
	my ($self, $item) = @_;
	state $d;
	for my $field (qw(content description title)) {
		if ($item->{$field} && $item->{$field} =~ /\<script/) {
			$d ||= Mojo::DOM->new();
			$item->{$field} = $d->parse($item->{$field})->find('script')->remove()->to_xml;
		}
	}
}

1;
