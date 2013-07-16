package Hadashot;
use Mojo::Base 'Mojolicious';
use Hadashot::Backend;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');
  my $config = $self->plugin('Config', default => {
      db_type => 'mango',
      db_connect => 'mongodb://localhost:27017',
      db_name => 'hadashot',
      db_feeds => 'subs',
      db_items => 'items',
      db_raw_feeds => 'raw_feeds'
  });

  # our backend functionality:

  $self->helper( backend => sub {
    state $bak = Hadashot::Backend->new(
      conf => $config,
      ua => $self->ua,
      db => Mango->new($self->config->{'db_connect'})->db($self->config->{'db_name'}),

      ); 
    } );

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
