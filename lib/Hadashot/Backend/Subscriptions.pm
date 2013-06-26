package Hadashot::Backend::Subscriptions;
use Mojo::Base 'Mojo::Collection';

sub active {
  return $_[0]->grep(sub { $_[0]->{active} == 1 }); 
}

sub inactive {
  return $_[0]->grep(sub { $_[0]->{active} == 0 }); 
}

1;
