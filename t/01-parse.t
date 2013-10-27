use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(slurp);

use Mojolicious::Lite;
plugin 'FeedReader';

push @{app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');
my $t = Test::Mojo->new(app);


# tests lifted from XML::Feed

my %Feeds = (
    'atom.xml' => 'Atom',
    'rss10.xml' => 'RSS 1.0',
    'rss20.xml' => 'RSS 2.0',
);

## First, test all of the various ways of calling parse.
my $feed;
my $file = File::Spec->catdir($FindBin::Bin, 'samples', 'atom.xml');
$feed = $t->app->parse_rss($file);
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');
my $fh = Mojo::Asset::File->new(path => $file) or die "Can't open $file: $!";
$feed = $t->app->parse_rss($fh);
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');
# And dom:
my $tx = $t->app->ua->get('/atom.xml');
$feed = $t->app->parse_rss($tx->res->dom);
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');

# parse a string
my $str = slurp $file;
$feed = $t->app->parse_rss(\$str);
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');

# parse a URL - only works blocking so far :(
$feed = $t->app->parse_rss(Mojo::URL->new("/atom.xml"));
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');

## Then try calling all of the unified API methods.
for my $file (sort keys %Feeds) {
    my $path = File::Spec->catdir($FindBin::Bin, 'samples', $file);
    my $feed = $t->app->parse_rss($path) or die "parse_rss returned undef";
    #is($feed->format, $Feeds{$file});
    #is($feed->language, 'en-us');
    is($feed->{title}, 'First Weblog');
    is($feed->{htmlUrl}, 'http://localhost/weblog/');
    is($feed->{description}, 'This is a test weblog.');
    # my $dt = $feed->modified;
    # isa_ok($dt, 'DateTime');
    # $dt->set_time_zone('UTC');
    # is($dt->iso8601, '2004-05-30T07:39:57');
    # is($feed->author, 'Melody');

    my $entries = $feed->{items};
    is(scalar @$entries, 2);
    my $entry = $entries->[0];
    is($entry->{title}, 'Entry Two');
    is($entry->{link}, 'http://localhost/weblog/2004/05/entry_two.html');
#     $dt = $entry->issued;
#     isa_ok($dt, 'DateTime');
#     $dt->set_time_zone('UTC');
#     is($dt->iso8601, '2004-05-30T07:39:25');
    like($entry->{content}, qr/<p>Hello!<\/p>/);
    is($entry->{description}, 'Hello!...');
    is($entry->{'tags'}[0], 'Travel');
#    is($entry->author, 'Melody');
  # no id if no id in feed - just link
    ok($entry->{id});
}

$feed = $t->app->parse_rss('t/samples/rss20-no-summary.xml')
    or die "parse fail";
my $entry = $feed->{items}[0];
ok(!$entry->{summary});
like($entry->{content}, qr/<p>This is a test.<\/p>/);

$feed = $t->app->parse_rss('t/samples/rss10-invalid-date.xml')
    or die "parse fail";
$entry = $feed->{items}[0];
ok(!$entry->{issued});   ## Should return undef, but not die.
ok(!$entry->{modified}); ## Same.

# summary vs. itunes:summary:

$feed = $t->app->parse_rss('t/samples/itunes_summary.xml')
  or die "parse failed";
$entry = $feed->{items}[0];
isnt($entry->{summary}, 'This is for &8220;itunes sake&8221;.');
is($entry->{description}, 'this is a <b>test</b>');
is($entry->{content}, '<p>This is more of the same</p>
');

# Let's do some errors - trying to parse html responses, basically
my $feed = $t->app->parse_rss( $t->app->ua->get('/link1.html')->res->dom );
ok(! exists $feed->{items}, 'no entries from html page');
ok(! exists $feed->{title}, 'no title from html page');
ok(! exists $feed->{description}, 'no description from html page');
ok(! exists $feed->{htmlUrl}, 'no htmlUrl from html page');
done_testing();
