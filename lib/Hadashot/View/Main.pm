package Hadashot::View;
use Mojo::Base 'Mojolicious::Controller';

sub main {
  my ($self) = @_;
  $self->render();
}

1;

