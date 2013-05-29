package Hadashot;
use Mojo::Base 'Mojolicious';
use Text::Haml;
use feature 'state';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->any('/(:controller)/(:action)')->to(controller => 'settings', action =>
  'import');
#  $r->get('/')->to('example#welcome');
#  $r->any('/import')->to('settings#import');
#	$r->get('/bookmark/add')->to('bookmark#add');
#  $r->get('/bookmark/list')->to('bookmark#list');

  # haml voodoo
  $self->helper(haml => sub { 
		state $h = Text::Haml->new();
		my $c = shift;
		my ($block) = pop @_; # we expect a sub ref which is created with begin/end tags
		print STDERR "haml helper called with ", join q{ }, @_, $block->();
		my $r = 'empty result';
		eval { 
			$r = $h->render($block->(), @_);
			print "T:Haml returned:\n", $r, "\n";
		};
		if ($@) {
			print "Ooops. $@\n";
		}	
			return Mojo::ByteStream->new($r);
	});
}

1;
