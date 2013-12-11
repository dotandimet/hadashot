package Hadashot;
use Mojo::Base 'Mojolicious';
use Hadashot::Backend;
use List::Util qw(shuffle);

our $VERSION = '0.01';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');
  $self->plugin('BootstrapTagHelpers');
  $self->plugin('FeedReader');
  my $config = $self->plugin(
    'Config',
    default => {
      db_type      => 'mango',
      db_connect   => 'mongodb://localhost:27017',
      db_name      => 'hadashot',
      db_feeds     => 'subs',
      db_items     => 'items',
      db_bookmarks => 'bookmarks',
      db_raw_feeds => 'raw_feeds',
      secret       => 'zasdcwdw2d'
    }
  );
  $self->secret($self->config->{'secret'});

  # our backend functionality:

  $self->helper(
    backend => sub {
      state $bak = Hadashot::Backend->new(
        conf => $config,
        queue => Hadashot::Backend::Queue->new(ua => $self->ua),
        log  => $self->log
      );
    }
  );

  $self->helper(todate => sub { Hadashot::Backend::time2str($_[1] / 1000); });

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->any('/(:controller)/(:action)')
    ->to(controller => 'settings', action => 'blogroll');

#  $r->get('/')->to('example#welcome');
#  $r->any('/import')->to('settings#import');
# $r->get('/bookmark/add')->to('bookmark#add');
#  $r->get('/bookmark/list')->to('bookmark#list');

}

sub fetch_subscriptions {
  my ($self, $check_all) = @_;
  my $subs;
  if ($check_all) {
    $subs = $self->backend->feeds->find()->all();
  }
  else {
    $subs = $self->backend->feeds->find({"active" => 1})->all();
  }
  my %all = map { $_->{xmlUrl} => $_ } @$subs;
  sub cb {
    my $url = shift;
    return sub {
      delete $all{$url};
      $self->backend->log->info('Operation -- COMPLETE!')
        if (0 == scalar keys %all);
    }
  };
  my $total = scalar @$subs;
  $self->ua->max_redirects(5)->connect_timeout(30);
  $self->backend->log->info("Will check $total feeds");
  foreach my $sub (@$subs) {
    $self->backend->queue->get(
        $sub->{xmlUrl}, $self->set_req_headers($sub),
        sub {
          my ($ua, $tx) = @_;
          $self->process_feed(
            $sub, $tx,
            sub {
              my ($c, $sub, $feed, $info) = @_;
              if (!$feed) {
                my $err = $info->{'error'};
                unless ($err) {
                  print STDERR "No feed and no error message, ",
                    $self->app->dumper($info);
                }
                $self->backend->log->warn("Problem getting feed:", $sub->{xmlUrl}, $err);
                if ($err eq 'url no longer points to a feed'
                    || $err eq 'Not Found' ) {
                  $self->backend->feeds->remove({xmlUrl => $sub->{xmlUrl}}, cb($sub->{xmlUrl}));
                }
                elsif ($err eq 'Not Modified') {
                  return;
                }
                else {
                  $sub->{active} = 0;
                  $sub->{error} = $err;
                  $self->backend->save_subscription($sub, cb($sub->{xmlUrl}));
               }
              }
              else {
                $sub->{active} = 1;
                $self->backend->update_feed( $sub, $feed,cb($sub->{xmlUrl}) );
              }
            }
          );
          }
    );
  };
  $self->backend->queue->process();
}

1;
