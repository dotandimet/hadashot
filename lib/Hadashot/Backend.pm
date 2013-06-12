package Hadashot::Backend;
use Mojo::Base -base;

use Mojo::DOM;
use Mojo::JSON;
use Mojo::Util qw(decode slurp);
use Mojo::Collection;
use Mojo::IOLoop;
use Mango;

has subscriptions => sub { Mojo::Collection->new(); };
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
  $this->subscriptions( Mojo::Collection->new(values %subscriptions) );
  return $this;
}

sub load_subs {
  my ($self) = @_;
  my $coll = $self->db()->collection('subs');
  my $subs = $coll->find()->all;
  $self->subscriptions(Mojo::Collection->new(@$subs));
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
  my ($self) = @_;
  my $ua = $self->ua;
  my ($hits, $errs) = (0,0);
  my $total = $self->subscriptions->size;
  my $delay = Mojo::IOLoop->delay(sub {
    say "Done - got $hits hits and $errs errors out of $total feeds";
  });
  $ua->max_redirects(5)->connect_timeout(30);
  say "Will check $total feeds";
  for my $sub ($self->subscriptions->each) {
    my $url = $sub->{xmlUrl};
    my $end = $delay->begin(0);
    $ua->head($url => sub {
      my ($ua, $tx) = @_;
      if (my $res = $tx->success) {
        print $url, " :-) ", $tx->res->code, "\n";
        $hits++;
      }
      else {
        my ($err, $code) = $tx->error;
        say $url, " :-( ", ( $code ? "$code response $err" : "connection error: $err" );
        $errs++;
      }
      $end->();
  #    $delay->end($tx->res->dom->at('description')->text);
    });
  }
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
	my ($self, $rss_file) = @_;
  my $rss_str  = decode 'UTF-8', (ref $rss_file) ? $rss_file->slurp : slurp $rss_file;
  my $d = Mojo::DOM->new($rss_str);
	my $items = $d->find('item');
	foreach my $item ($items->each) {
		my %h;
		foreach my $k (qw(title link summary content description content\:encoded)) {
			my $p = $item->at($k);
			if ($p) {
				$h{$k} = $p->text;
			}
		}
		say Mojo::JSON->new->encode(\%h);
	}
	# get channel properties:
	#foreach my $k (qw(
}
1;
