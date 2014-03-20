use Mojo::Base -strict;

use utf8;
use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(slurp dumper);
use FindBin;

use Hadashot::Backend;


BEGIN {
  $ENV{'MOJO_CONFIG'} = File::Spec->catdir($FindBin::Bin, 'test.conf');
  binmode STDERR, ':utf8';
  binmode STDOUT, ':utf8';
}

my $t = Test::Mojo->new('Hadashot');
push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

$t->app->log->path(undef);    # log to STDERR?
print $t->app->config->{db_name}, " is the db\n";
$t->app->backend->setup();
$t->app->backend->reset();

# Add Subscription:
$t->post_ok('/settings/add_subscription', form => {url => '/atom.xml'})
  ->status_is(302)
  ->header_like(Location => qr{/view/feed\?src=http.*/atom\.xml});


# Add remote URL:
$t->post_ok('/settings/add_subscription', form => {url => 'http://corky.net'})
  ->status_is(302)
  ->header_like(Location => qr{/view/feed\?src=http.*corky.*});

# Check blogroll:
$t->get_ok('/settings/blogroll?js=1')
  ->status_is(200)
  ->json_is('/subs/0/title', 'קורקי.נט aggregator');

# Upload subscriptions from OPML file:
$t->post_ok(
  '/settings/import_opml',
  form => {
    infile => {file => File::Spec->catdir($FindBin::Bin, 'sample.opml')},
    type   => 'OPML'
  }
)->status_is(302)->header_like(Location => qr{/settings/blogroll});

# Check loading a feed and fetching items to display:
$t->app->backend->fetch_subscriptions('http://oglaf.com/feeds/rss/'); # feed with no dates
my $page_1 = Mojo::URL->new('/feed/river/')->query({js => 1, src => 'http://oglaf.com/feeds/rss/'});
my $first = $t->get_ok($page_1)->status_is(200)->json_is('/total', $t->app->config->{'max_items'} || '8')->tx->res->json->{items}[0];




done_testing();

