package Hadashot::Backend;
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
has db => sub { Mango->new('mongodb://localhost:27017')->db('hadashot'); };
has json => sub { Mojo::JSON->new(); };
has ua => sub { Mojo::UserAgent->new(); };

sub parse_opml {
  my ($self, $opml_file) = @_;
  my $this = (ref $self) ? $self : Hadashot::Backend->new();
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
  $this->subscriptions( Hadashot::Backend::Subscriptions->new(values %subscriptions) );
  return $this;
}

sub load_subs {
  my ($self) = @_;
  my $coll = $self->db()->collection('subs');
  my $subs = $coll->find()->all;
  $self->subscriptions(Hada->new(@$subs));
}

sub annotate_bidi {
  my ($self) = @_;
  for my $sub ($self->subscriptions->each) {
     my $is_bidi = ($sub->{title} =~ /\p{Hebrew}+/);
     if ($is_bidi) {
 	$sub->{'rtl'} = 1;
     }
  }
}

sub fetch_subscriptions {
  my ($self, $active) = @_;
  my $ua = $self->ua;
  my ($hits, $errs) = (0,0);
  my $subs = (defined $active) ? $self->subscriptions->map(sub {
  shift->{active} }) : $self->subscriptions;
    my $subs = 
  }
  my $total = $subs->size;
  my $delay = Mojo::IOLoop->delay(sub {
    say "Done - got $hits hits and $errs errors out of $total feeds";
		my $read = $subs->grep(sub { $_[0]->{'active'} == 1 })->size;
		say " Marked $read active feeds";
    if ($total > $read) {
      my $inactive = $subs->grep(sub { 
      say " Marked 
    }
  });
  $ua->max_redirects(5)->connect_timeout(30);
  say "Will check $total feeds";

  $self->subscriptions->each(sub {
    my $sub = shift;
    my $url = $sub->{xmlUrl};
    my $end = $delay->begin(0);
    $ua->get($url => sub {
      my ($ua, $tx) = @_;
      if (my $res = $tx->success) {
        if ($tx->res->code == 200) {
        say $url, " :-) ", $tx->res->code
          , " ",
          $tx->res->headers->last_modified,
          " ", $tx->res->headers->etag;
        #  $self->load_rss($res->content->asset);
					say "=====";	
					say $tx->res->body;
					say "=====";	
					$sub->{'active'} = 1;
        }
				else { say "$url :-( " , $tx->res->code; };
        $hits++;
      }
      else {
        my ($err, $code) = $tx->error;
        say $url, " :-( ", ( $code ? "$code response $err" : "connection error: $err" );
        $errs++;
				$sub->{'active'} = 0;
      }
      $end->();
  #    $delay->end($tx->res->dom->at('description')->text);
    });
  });
  $delay->wait unless Mojo::IOLoop->is_running;
}

sub parse_json_collection {
	my ($self, $file) = @_;
	my $str = slurp $file;
	my $obj = Mojo::JSON->new->decode($str);
	my $items = delete $obj->{'items'};
	foreach my $item (@$items) {
		
	}
	my $props = $obj;
}

sub cleanup_reader_fields {
	my ($self, $item) = @_;
	
}

sub load_rss {
{
	my ($self, $rss_file) = @_;
  my $rss_str  = decode 'UTF-8', (ref $rss_file) ? $rss_file->slurp : slurp $rss_file;
  my $d = Mojo::DOM->new($rss_str);
	my $items = $d->find('item');
	my $entries = $d->find('entry'); # Atom
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
    {
		say Mojo::JSON->new->encode(\%h);
	}
	# get channel properties:
	#foreach my $k (qw(
}
1;
