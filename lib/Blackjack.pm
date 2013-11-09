use strict;
use warnings;
package Blackjack;

use Mojo::Base 'Mojo::UserAgent';

# my own user agent, with Blackjack and ...

has max_active => sub { shift->max_connections }; # is this a good default?


sub start {
  my ($self, $tx, $cb) = @_;
  unless ($self->{'active'}) {
    $self->{'active'} = 0;
    $self->on(start => sub { shift->{'active'}++ });
  }
  $tx->on('finish' => sub { $self->check_queued(@_); });
  if ( $self->{active} < $self->max_active ) { # we can do more
      $self->SUPER::start($tx, $cb);
  }
  else {
      $self->{queued_tx} ||= [];
      push @{$self->{queued_tx}}, [$tx, $cb];
  }
}

sub check_queued {
  my ($self, $tx) = @_;
  $self->{'active'}--;
  my $queue = $self->{queued_tx};
  if ($ENV{BLACKJACK_DEBUG}) {
    print STDERR "Called by ", $tx->req->method, ' ', $tx->req->url, "\n";
    print STDERR $self->{active}, " active transactions in check_queued\n";
    print STDERR scalar @$queue , " items in queue\n";
  }
  if (@$queue) {
    my $next = pop @$queue;
    $self->start(@$next);
  }
}

1;


