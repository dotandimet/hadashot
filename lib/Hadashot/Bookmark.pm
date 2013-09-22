package Hadashot::Bookmark;
use Mojo::Base 'Mojolicious::Controller';

sub add {
  my ($self) = @_;
  if ($self->param('bookmark')) {
    
  }
  $self->backend
}

sub list {
  my ($self) = @_;
  $self->render( json => $self->backend->bookmarks->find()->all() );
}

1;

