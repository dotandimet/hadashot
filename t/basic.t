use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Hadashot');

# use test config, set up test:
$t->app->config({ %{$t->app->config}, db_name => 'hadashotest', db_feeds => 'feeds', db_items => 'items' });
my $b = $t->app->backend;
$b->reset();
$b->setup();

$t->get_ok('/')->status_is(200)->content_like(qr/Look/i);
say $t->app->dumper($t->app->config);
done_testing();
