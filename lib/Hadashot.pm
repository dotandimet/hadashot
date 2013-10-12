package Hadashot;
use Mojo::Base 'Mojolicious';
use Hadashot::Backend;
use List::Util qw(shuffle);

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');
  $self->plugin('BootstrapTagHelpers');
  $self->plugin('FeedReader');
  my $config = $self->plugin('Config', default => {
      db_type => 'mango',
      db_connect => 'mongodb://localhost:27017',
      db_name => 'hadashot',
      db_feeds => 'subs',
      db_items => 'items',
      db_bookmarks => 'bookmarks',
      db_raw_feeds => 'raw_feeds',
      secret => 'zasdcwdw2d'
  });
  $self->secret($self->config->{'secret'});
  # our backend functionality:

  $self->helper( backend => sub {
    state $bak = Hadashot::Backend->new(
      conf => $config,
      ua => $self->ua,
			log => $self->log
      ); 
    } );

  $self->helper( todate => sub { Hadashot::Backend::time2str($_[1] / 1000); } );

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->any('/(:controller)/(:action)')->to(controller => 'settings', action => 'blogroll');
#  $r->get('/')->to('example#welcome');
#  $r->any('/import')->to('settings#import');
#	$r->get('/bookmark/add')->to('bookmark#add');
#  $r->get('/bookmark/list')->to('bookmark#list');
  
}

sub fetch_subscriptions {
  my ($self, $check_all, $limit) = @_;
  my $ua = $self->ua;
  $ua->max_redirects(5)->connect_timeout(30);
  my $subs;
  if ($check_all) {
    $subs = $self->backend->feeds->find()->all();
  }
  else {
    $subs = $self->backend->feeds->find({ "active" => 1 })->all();
  }
  $subs = [ shuffle @$subs ];
  $subs = (defined $limit && $limit > 0 && $limit <= $#$subs) ?  @$subs[0..$limit] : $subs;
  my @all = @$subs;
  my $total = scalar @$subs;
  $self->log->info( "Will check $total feeds" );
  $self->process_feeds($subs, sub {
    my ($self, $sub, $feed, $code, $err) = @_;
    if (!$feed) {
     print STDERR "Problem getting feed:",
      (($code) ? "Error code $code" : ''),
      (($err) ? "Error $err" : '');
    }
    $self->backend->update_feed($sub, $feed) if ($feed);
    $self->backend->feeds->update({ _id => $sub->{'_id'} }, $sub);
 });
}

1;
