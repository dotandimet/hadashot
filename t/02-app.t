use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(slurp);
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

$t->app->backend->setup();
$t->app->backend->reset();

$t->post_ok('/settings/add_subscription', form => {
  url => '/atom.xml'
})->status_is(200) # actually, it should be a redirect
  ->content_like(qr/blah/, 'what did we get?');

done_testing();

