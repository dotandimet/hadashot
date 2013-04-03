package Hadashot::Backend::Subscriptions;
use Mojo::Base 'Mojo::Collection';

use Mojo::DOM;
use Mojo::Util qw(decode slurp);
use Mojo::Collection;
use Mojo::IOLoop;
use Mango;

sub new_from_opml {
  my ($self, $opml_dom) = @_;
  my (%subscriptions, %categories);
  for my $item ($opml_dom->find(q{outline})->each) {
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
  });
  for my $sub ($self->subscriptions->each) {
    $delay->begin;
    my $url = $sub->{xmlUrl};	
    $ua->get($url => sub {
      my ($ua, $tx) = @_;
      print $url, " ", $tx->res->code, "\n";
      $delay->end($tx->res->dom->at('title')->text);
    });
  }
  $delay->wait unless Mojo::IOLoop->is_running;

}

1;
