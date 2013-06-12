package Hadashot;
use Mojo::Base 'Mojolicious';
use Hadashot::Backend;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # our backend functionality:

  $self->helper(backend => sub { state $bak = Hadashot::Backend->new(ua => $self->ua) });

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->any('/(:controller)/(:action)')->to(controller => 'settings', action =>
  'import');
#  $r->get('/')->to('example#welcome');
#  $r->any('/import')->to('settings#import');
#	$r->get('/bookmark/add')->to('bookmark#add');
#  $r->get('/bookmark/list')->to('bookmark#list');
  
}

1;
