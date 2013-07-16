package Hadashot::Backend;
use v5.016;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::JSON;
use Mojo::Util qw(decode slurp);
use Mojo::Collection;
use Mojo::IOLoop;
use Mango;
use HTTP::Date;
use Hadashot::Backend::Subscriptions;

has subscriptions => sub { Hadashot::Backend::Subscriptions->new(); };
# has items => sub { Hadashot::Backend::Items->new(); };
has db => sub { Mango->new('mongodb://localhost:27017')->db('hadashot'); };
has json => sub { Mojo::JSON->new(); };
has ua => sub { Mojo::UserAgent->new(); };
has feeds => sub { $_[0]->db()->collection('subs') };
has items => sub { $_[0]->db()->collection('items') };

sub parse_opml {
  my ($self, $opml_file) = @_;
  my $opml_str  = decode 'UTF-8', (ref $opml_file) ? $opml_file->slurp : slurp $opml_file;
  my $d = Mojo::DOM->new($opml_str);
  my (%subscriptions, %categories);
  for my $item ($d->find(q{outline})->each) {
	my $node = $item->attrs;
	if (!defined $node->{type} || $node->{type} ne 'rss') {
	  my $cat = $node->{title} || $node->{text};
	  $categories{$cat} = $item->children->pluck('attrs', 'xmlUrl');
	}
	else { # file by RSS URL:
	  $subscriptions{ $node->{xmlUrl} } = $node;
	}
  }
  # assign categories
  for my $cat (keys %categories) {
	print "category $cat\n";
	for my $rss ($categories{$cat}->each) {
		$subscriptions{$rss}{'categories'} ||= [];
		push @{$subscriptions{$rss}{'categories'}}, $cat;
	}
  }
  return (values %subscriptions);
}

sub load_subs {
  my ($self) = @_;
  $DB::single=1;
  my $subs = $self->feeds->find()->all;
  $self->subscriptions(Hadashot::Backend::Subscriptions->new(@$subs));
}

sub annotate_bidi {
  my ($self, $sub ) = @_;
  my $is_bidi = ($sub->{title} =~ /\p{Hebrew}+/);
  if ($is_bidi) {
 	  $sub->{'rtl'} = 1;
  }
}

sub fetch_subscriptions {
  my ($self, $check_all) = @_;
  my $ua = $self->ua;
  $ua->max_redirects(5)->connect_timeout(30);
  my $subs = (defined $check_all) ? $self->subscriptions : $self->subscriptions->active(); 
  my $total = $subs->size;
  say "Will check $total feeds";
  $self->process_feeds($subs, sub {
    my $self = shift;
    my $subs = $self->subscriptions;
    say "Marked ", $subs->active()->size, " feeds as active and ", 
        $subs->inactive()->size , " as inactive";
  });
}

sub process_feeds {
  my ($self, $subs, $cb) = @_;
  state $delay = Mojo::IOLoop->delay(sub { say ((@$subs) ? "Ended before queue exhausted! " : "Done"); $self->$cb; });
  state $active = 0;
  my $max_concurrent = 8;
  while ( $active < $max_concurrent and my $sub = shift @$subs ) {
    my $url = $sub->{xmlUrl};
    $active++;
    my $end = $delay->begin(0);
    $self->ua->get($url => sub {
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
      my $last_modified = $tx->res->headers->last_modified || '';
      my $etag = $tx->res->headers->etag || '';
      say $url, " :-) ", $tx->res->code
        , " ", $last_modified, " ", $etag;
      my $items = $self->parse_rss($res->content->asset,
      sub {
        my ($self, $item) = @_;
        $self->items->update($item, { upsert => 1 });
      });
      say "=====";	
      say $tx->res->body;
      say "=====";	
      $sub->{'active'} = 1;
    }
    else { say "$url :-( " , $tx->res->code; };
  }
  else {
    my ($err, $code) = $tx->error;
    say $url, " :-( ", ( $code ? "$code response $err" : "connection error: $err" );
    $sub->{'active'} = 0;
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
		my %h;
		foreach my $k (qw(title link summary content description content\:encoded pubDate published updated dc\:date)) {
			my $p = $item->at($k);
			if ($p) {
				$h{$k} = $p->text;
				if ($k eq 'pubDate' || $k eq 'published' || $k eq 'updated' || $k eq 'dc\:date') {
					$h{$k} = str2time($h{$k});
				}
			}
		}
		# normalize fields:
		my %replace = ( 'content\:encoded' => 'content', 'pubDate' => 'published', 'dc\:date' => 'published' );
		while (my ($old, $new) = each %replace) {
		if ($h{$old}) {
			$h{$new} = delete $h{$old};
		}
    }
     if ($cb) {
        $self->$cb(\%h);
     }
     push @$res, \%h;
	}
	# get channel properties:
	#foreach my $k (qw(
  return $res;
}

1;
