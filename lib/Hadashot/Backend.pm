package Hadashot::Backend;
use Mojo::Base -base;

use Mojo::DOM;
use Mojo::Util qw(decode slurp);
use Mojo::Collection;

has subscriptions => sub { Mojo::Collection->new(); };

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

sub annotate {
  my ($self) = @_;
  for my $sub ($self->subscriptions->each) {
     my $is_bidi = ($sub->{title} =~ /\p{Hebrew}+/);
     if ($is_bidi) {
 	$sub->{'rtl'} = 1;
     }
  }
}

1;
