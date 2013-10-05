use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;

my $t = Test::Mojo->new('Hadashot');

# tests lifted from XML::Feed

my %Feeds = (
    't/samples/atom.xml' => 'Atom',
    't/samples/rss10.xml' => 'RSS 1.0',
    't/samples/rss20.xml' => 'RSS 2.0',
);

## First, test all of the various ways of calling parse.
my $feed;
my $file = 't/samples/atom.xml';
$feed = $t->app->backend->parse_rss($file);
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');
my $fh = Mojo::Asset::File->new(path => $file) or die "Can't open $file: $!";
$feed = $t->app->backend->parse_rss($fh);
isa_ok($feed, 'HASH');
is($feed->{title}, 'First Weblog');
# parse a string, not implemented
# seek $fh, 0, 0;
# my $xml = do { local $/; <$fh> };
# $feed = $t->app->backend->parse_rss(\$xml);
# isa_ok($feed, 'XML::Feed::Format::Atom');
# is($feed->{title}, 'First Weblog');

# parse a URL, not implemented
# $feed = $t->app->backend->parse_rss(URI->new("file:$file"));
# isa_ok($feed, 'XML::Feed::Format::Atom');
# is($feed->{title}, 'First Weblog');

## Then try calling all of the unified API methods.
for my $file (sort keys %Feeds) {
    my $feed = $t->app->backend->parse_rss($file) or die "parse_rss returned undef";
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

$feed = $t->app->backend->parse_rss('t/samples/rss20-no-summary.xml')
    or die "parse fail";
my $entry = $feed->{items}[0];
ok(!$entry->{summary});
like($entry->{content}, qr/<p>This is a test.<\/p>/);

$feed = $t->app->backend->parse_rss('t/samples/rss10-invalid-date.xml')
    or die "parse fail";
$entry = $feed->{items}[0];
ok(!$entry->{issued});   ## Should return undef, but not die.
ok(!$entry->{modified}); ## Same.

done_testing();
