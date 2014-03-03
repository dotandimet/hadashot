use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(slurp dumper);
use FindBin;

use Hadashot::Backend;

my $t = Test::Mojo->new('Hadashot');

$t->app->config({
      db_type      => 'mango',
      db_connect   => 'mongodb://localhost:27017',
      db_name      => 'hadashot_test_02',
      db_feeds     => 'subs',
      db_items     => 'items',
      db_bookmarks => 'bookmarks',
      db_raw_feeds => 'raw_feeds',
      secret       => 'dsfsfw2dfAg5%gh'
});

push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

$t->app->log->path(undef); # log to STDERR?
$t->app->backend->setup();
$t->app->backend->reset();

# Add Subscription:
$t->post_ok('/settings/add_subscription', form => {
  url => '/atom.xml'
})->status_is(302) # actually, it should be a redirect
  ->header_like(Location => qr{/view/feed\?src=http.*/atom\.xml});

done_testing();

