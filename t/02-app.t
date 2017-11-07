use Mojo::Base -strict;

use utf8;
use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(dumper url_escape decode);
use FindBin;

use Hadashot::Backend;

# Voodoo to prevent wide characters in output,
# see here: https://metacpan.org/pod/Test::More#utf8-Wide-character-in-print
my $builder = Test::More->builder;
binmode $builder->output,         ":encoding(UTF-8)";
binmode $builder->failure_output, ":encoding(UTF-8)";
binmode $builder->todo_output,    ":encoding(UTF-8)";

BEGIN {
  $ENV{'MOJO_CONFIG'} = File::Spec->catdir($FindBin::Bin, 'test.conf');
}

my $t = Test::Mojo->new('Hadashot');
push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

$t->app->log->path(undef);    # log to STDERR?
print $t->app->config->{db_name}, " is the db\n";
$t->app->backend->setup();
$t->app->backend->reset();

my $base = $t->app->ua->server->nb_url; # this is the base URL my app sees.
diag("base url for app ua server is $base");
my $face = $t->ua->server->nb_url; # this is the base URL my tests see.
diag("base url for test ua server is $face");
my $xml_url = $t->get_ok('/atom.xml')->status_is(200)->content_type_is('application/xml')->tx->req->url;
diag "Got atom.xml from $xml_url";

# rewrite URL to how the app sees it
$xml_url = $base->clone->path($xml_url->path);
diag "Set xml_url to $xml_url\n";
my $url_encoded_xml_url = url_escape($xml_url);
# Add Subscription:
my $add_sub_url =
$t->post_ok('/settings/add_subscription', form => {url => '/atom.xml' })
  ->status_is(302)
  ->header_like(Location => qr{/view/feed\?src=$url_encoded_xml_url})->tx->req->url;

$t->get_ok('/settings/blogroll?js=1')->status_is(200)
  ->content_type_is('application/json;charset=UTF-8')->json_is('/subs/0/xmlUrl' => $xml_url)
  ->json_is('/subs/0/title' => 'First Weblog');


# Add remote URL:
$t->post_ok('/settings/add_subscription', form => {url => 'http://corky.net'})
  ->status_is(302)
  ->header_like(Location => qr{/view/feed\?src=http.*corky.*});

# Check blogroll:
$t->get_ok('/settings/blogroll?js=1')
  ->status_is(200)
  ->content_type_is('application/json;charset=UTF-8')
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
