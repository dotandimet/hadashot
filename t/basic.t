use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;

my $t = Test::Mojo->new('Hadashot');

# use test config, set up test:
$t->app->config({ %{$t->app->config}, db_name => 'hadashotest', db_feeds => 'feeds', db_items => 'items' });
my $b = $t->app->backend;
$b->reset();
$b->setup();

# Serve the test feeds to parse and fetch
push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

$t->get_ok('/atom.xml')->status_is(200)->content_type_is('application/xml')
  ->text_is('feed title' => 'First Weblog');

# add a subscription:
$b->save_subscription({xmlUrl => '/atom.xml', title => 'first'});

# fetch it:
# parse and load a feed:
my $delay = Mojo::IOLoop->delay;
$delay->on(error => sub { die "Horrors: ", @_, "\n"; });
$t->app->parse_rss(
  Mojo::URL->new('/atom.xml'),
  sub {
    my ($c, $feed) = @_;
    $b->update_feed({xmlUrl => '/atom.xml'}, $feed, $delay->begin());
  }
);
$delay->wait unless (Mojo::IOLoop->is_running);

# fetch it:
$t->get_ok('/feed/river?js=1')->json_is('/total', 2)->json_is('/items/0/tags', ["Travel"]);

# reset eveything:

$b->reset();
$b->setup();

# add a subscription via web:

$t->post_ok('/settings/add_subscription', form => {url => '/link1.html'})->status_is(302)->header_like(Location => qr{view/feed\?src=.+/atom\.xml$});

# fetch it:
say $t->get_ok('/settings/blogroll?js=1')->status_is(200)
  ->content_type_is('application/json')->json_is('/subs/0/items' => 2)
  ->json_is('/subs/0/title' => 'First Weblog')->tx->res->body;

# read it:
$t->get_ok('/feed/river?js=1')->json_is('/total', 2)->json_is('/items/0/tags', ["Travel"]);


done_testing();
