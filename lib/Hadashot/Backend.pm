package Hadashot::Backend;
use v5.016;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::JSON;
use Mojo::Util qw(decode slurp trim);
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
has bookmarks => sub { $_[0]->db()->collection($_[0]->conf->{'db_bookmarks'}) };
has log => sub { Mojo::Log->new() };

sub setup {
  my ($self) = @_;
  $self->feeds->create();
  $self->items->create();
  $self->items->ensure_index({published => -1});
  $self->items->ensure_index({origin => 1});
}

sub reset { # wanna drop all your data? cool.
	my ($self) = @_;
	$self->feeds->drop();
	$self->items->drop();
	$self->log->info('dropped all subs and items');
}

sub parse_opml {
  my ($self, $opml_file) = @_;
  my $opml_str  = decode 'UTF-8', (ref $opml_file) ? $opml_file->slurp : slurp $opml_file;
  my $d = $self->dom->parse($opml_str);
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
	$self->log->debug( "category $cat\n" );
	for my $rss ($categories{$cat}->each) {
		$subscriptions{$rss}{'categories'} ||= [];
		push @{$subscriptions{$rss}{'categories'}}, $cat;
	}
  }
  return (values %subscriptions);
}

sub save_subscription {
    my ( $self, $sub, $cb ) = @_;
    unless ($sub->{xmlUrl} && $sub->{title}) { 
      $self->log->warn("Missing fields - will not save object" .
      $self->json($sub));
      return; # will not call your callback, will return undef.
    }
    my $doc;
#    $sub->{direction} = $self->get_direction( $sub->{'title'} );  # set rtl flag
    $doc =
      $self->feeds->find_one( { xmlUrl => $sub->{xmlUrl} } );
    unless ($doc) {
        my $oid = $self->feeds->insert($sub);
        if ($oid) {
            $self->log->info( $sub->{title}, " stored with id $oid\n" );
            $doc = { %$sub, _id => $oid };
        }
    }
    if ( $cb && ref $cb eq 'CODE' ) {
        $cb->($doc);
    }
    else {
        return $doc;
    }
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
          my $feed = pop;
          # update sub general properties
          for my $field (qw(title subtitle description htmlUrl)) {
            if ($feed->{$field} && ( ! exists $sub->{$field} ||
            $feed->{$field} ne $sub->{$field} )) {
                $sub->{$field} = $feed->{$field};
            }
          }
          foreach my $item (@{$feed->{'items'}}) {
  					$item->{'origin'} = $url; # save our source feed...
            # fix relative links - because Sam Ruby is a wise-ass
            $item->{'link'} = $self->abs_url($item->{'link'}, $item->{'origin'});
           if ($item->{'link'} =~ m/feedproxy/) { # cleanup feedproxy links
              $self->unshorten_url($item->{'link'}, sub {
                $item->{'link'} = $self->cleanup_feedproxy($_[0]);
					      $self->store_feed_item( $item ); 
            } );
          } else {
  					$self->store_feed_item( $item );
          }  
				 }
			 }
			);
      $sub->{'active'} = 1;
    }
		elsif ($tx->res->code == 304) { # not modified
			$self->log->info("$url :-) " . $tx->res->code . " " . $tx->res->message);
      $sub->{'active'} = 1;
		}
    else { $self->log->info( "$url :-( " . $tx->res->code . " " . $tx->res->message); };
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
  my $d = $self->dom->parse($rss_str);
  my $feed = $self->parse_rss_channel($d); # Feed properties
	my $items = $d->find('item');
	my $entries = $d->find('entry'); # Atom
  my $res = [];
	foreach my $item ($items->each, $entries->each) {
		push @$res, $self->parse_rss_item($item);
	}
	# get channel properties:
	#foreach my $k (qw(
  if (@$res) {
    $feed->{'items'} = $res;
  }
 	if ($cb) {
    $self->$cb($feed);
	}
 return $feed;
}

sub parse_rss_channel {
  my ($self, $dom) = @_;
  my $info = {};
  foreach my $k (qw{title subtitle description link:not([rel])}) {
    my $p = $dom->at("channel > $k") || $dom->at("feed > $k"); # direct child
    if ($p) {
      $info->{$k} = $p->text || $p->content_xml || $p->attr('href');
    }
  }
  $info->{htmlUrl} = delete $info->{'link:not([rel])'};
  
  $self->log->debug("Parsed feed info from rss: " . $self->json->encode($info) );
  return $info;
}

sub parse_rss_item {
		my ($self, $item) = @_;
		my %h;
		foreach my $k (qw(title id summary guid content description content\:encoded pubDate published updated dc\:date)) {
			my $p = $item->at($k);
			if ($p) {
				$h{$k} = $p->text || $p->content_xml;
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
		# find tags:
		my @tags;
		$item->find('category')->each(sub { push @tags, $_[0]->text || $_[0]->attr('term') } );
		if (@tags) {
			$h{'tags'} = \@tags;
		}
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

sub set_item_direction {
  my ($self, $item) = @_;
	for my $field (qw(content description title)) {
    if ($item->{$field}) {
      $item->{$field} = { dir => $self->get_direction($item->{$field}), content => $item->{$field} };
    }
  }
  return $item;
}

# sanitize_item is a trivial method that only cleans up things that I
# noticed caused problems when displaying the feed HTML. I threw in font
# because it annoys me.
sub sanitize_item {
	my ($self, $item) = @_;
	for my $field (qw(content description title)) {
		if ($item->{$field} && $item->{$field} =~ /\<(script|base)/) {
			$item->{$field} = $self->dom->parse($item->{$field})->find('script,base')->remove()->to_xml;
		}
#    if ($item->{$field} && $item->{$field} =~ /\<font/) {
#      $item->{$field} = $self->dom->parse($item->{$field})->find('font')->strip();
#    }
	}
}

sub unshorten_url {
  my $self = shift;
  my $url  = shift;
  my $cb   = (ref $_[-1] eq 'CODE') ? pop : undef;
  my $final = $url;
  $self->ua->max_redirects(10);
  if ($cb) { # try non-blocking
  $self->ua->head($url, sub {
    my ($ua, $tx) = @_;
    if ($tx->success) {
    $self->log->info("Redirects " . join q{, }, map { $_->req->url }
    (@{$tx->redirects}) );
    $cb->($tx->req->url);
    } else {
      $self->log->error( $tx->error );
    }
  });
  }
  else {
    my $tx =$self->ua->head($url);
    return $tx->req->url;
  }
}
sub abs_url {
  my ($self, $url, $base) = @_;
  if (!$url || ! Mojo::URL->new($url)->host) {
    $url =
      Mojo::URL->new($base)->path($url)->to_abs->to_string;
  }
  return $url;
}
sub cleanup_feedproxy {
  my ($self, $url) = @_;
  for (qw(utm_source utm_medium utm_campaign)) {
    $url->query->remove($_);
  }
	return $url;
}

# find_feeds - get RSS/Atom feed URL from argument. 
# Code adapted to use Mojolcious from Feed::Find by Benjamin Trott
# Any stupid mistakes are my own
# I return hashrefs instead of string urls, use 
# find_feeds($url, sub { say $_->{xmlUrl} })
# to get just the url
sub find_feeds {
  my $self = shift;
  my $url  = shift;
  my $cb   = ( ref $_[-1] eq 'CODE' ) ? pop @_ : undef;
  my @feeds;
  $self->ua->max_redirects(5)->connect_timeout(30);
  if ($cb) {  # non-blocking
    $self->ua->get(
      $url,
      sub {
        my ( $ua, $tx ) = @_;
        if ( $tx->success ) {
          @feeds = $self->_find_feed_links( $url, $tx->res );
          $cb->(@feeds);
        }
        else {
          my ( $err, $code ) = $tx->error;
          $self->log->warn( $code
            ? "$code response: $err"
            : "Connection error: $err" );
        }
      }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  }
  else {
    my $tx = $self->ua->get($url);
    if ( $tx->success ) {
      @feeds = $self->_find_feed_links( $url, $tx->res );
    }
    else {
      my ( $err, $code ) = $tx->error;
      $self->log->warn(
        $code ? "$code response: $err" : "Connection error: $err" );
    }
  }
  return @feeds;
}

sub _find_feed_links {
  my ( $self, $url, $res ) = @_;
  my %is_feed = map { $_ => 1 } (

    # feed mime-types:
    'application/x.atom+xml',
    'application/atom+xml',
    'application/xml',
    'text/xml',
    'application/rss+xml',
    'application/rdf+xml',
  );
  state $feed_ext = qr/\.(?:rss|xml|rdf)$/;
  my @feeds;

  # use split to remove charset attribute from content_type
  my ($content_type) = split( /[; ]+/, $res->headers->content_type );
  if ( $is_feed{$content_type} ) {
    my $info = $self->parse_rss_channel( $res->dom );
    $info->{'xmlUrl'} = $url;
    $info->{'htmlUrl'} = $self->abs_url($info->{'htmlUrl'}, $url); # thank you Atom
    push @feeds, $info;
  }
  else {
  # we are in a web page. PHEAR.
    my $base =
      ( $res->dom->find('head base')->pluck( 'attr', 'href' )->join(q{})
        || $url );
    my $title = $res->dom->at('head > title')->text || $url;
    $res->dom->find('head link')->each(
      sub {
        my $attrs = $_->attr();
        return unless ( $attrs->{'rel'} );
        my %rel = map { $_ => 1 } split /\s+/, lc( $attrs->{'rel'} );
        my $type = ( $attrs->{'type'} ) ? lc trim $attrs->{'type'} : '';
        if ( $is_feed{$type}
          && ( $rel{'alternate'} || $rel{'service.feed'} ) )
        {
          push @feeds,
            {
            xmlUrl => $self->abs_url( $attrs->{'href'}, $base ),
            title  => join ' ', ( $title, $attrs->{'title'} || '' )
            };
        }
      }
    );
    $res->dom->find('a')->grep(
      sub {
        $_->attr('href')
          && Mojo::URL->new( $_->attr('href') )->path =~ /$feed_ext/io;
      }
      )->each(
      sub {
        push @feeds,
          {
          xmlUrl => $self->abs_url( $_->attr('href'), $base ),
          title  => $_->text || $_->attr('title') || $title
          };
      }
      );
  }
  return @feeds;
}

1;
