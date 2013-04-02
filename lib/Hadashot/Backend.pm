package Hadashot::Backend;
use Mojo::Base -base;

use Mojo::DOM;
use Mojo::Util qw(decode slurp);
use Mojo::Collection;
use Mojo::IOLoop;
use Mango;

has subscriptions => sub { Mojo::Collection->new(); };
has db => sub { Mango->new('mongodb://localhost:27017')->db('hadashot'); };

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
  my ($self, $ua) = @_;
  my $delay = Mojo::IOLoop->delay(sub {
    my ($delay, @titles) = @_;
    print "@titles\n";
  });
  $ua->max_redirects(5);
  for my $sub ($self->subscriptions->each) {
    my $url = $sub->{xmlUrl};
    $delay->begin;
    $ua->get($url => sub {
      my ($ua, $tx) = @_;
      print $url, " ", $tx->res->code, "\n";
      $delay->end("hey");
  #    $delay->end($tx->res->dom->at('description')->text);
    });
  }
  $delay->wait unless Mojo::IOLoop->is_running;

}

1;
