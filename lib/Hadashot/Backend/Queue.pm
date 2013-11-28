package Hadashot::Backend::Queue;
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::UserAgent;

has max => sub { 4 };
has active => { 0 };
has waiting => sub { [] };
has delay => sub { Mojo::IOLoop->delay() };
has ua => sub { Mojo::UserAgent->new() };

sub enqueue {
  my $self = shift;
  push @{$self->waiting}, @_;
}

sub dequeue {
  my $self = shift;
  return shift @{$self->waiting};
}

sub process {
  my ($self, $url, $headers, $cb, $data) = @_;

  
}

1;
