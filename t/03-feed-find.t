use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;

my $t = Test::Mojo->new('Hadashot');
push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

my @urls = 
(qw{ /atom.xml
http://corky.net http://www.intertwingly.net/blog/ http://corky.net/dotan/ http://corky.net/dotan/feed http://intertwingly.net/blog/index.atom http://www.ursulium.com http://arcfinity.tumblr.com/ http://arcfinity.tumblr.com/rss}
);

# my internal urls - needs work
#(qw{ /intertwingly.html /dotan_blog.html /corky.net_dotan_feed.xml /intertwingly.atom /ursulium.html /arcfinity.rss /arcfinity.html });

# foreach my $url (@urls) {
#   $t->get_ok($url)->status_is(200);
#   my ($feeds, $err, $code) = $t->app->find_feeds($url);
#   say "URL: $url $code $err found ", scalar @$feeds;
#   say $t->app->dumper($_) for @$feeds;
# }

# feed
    $t->get_ok('/atom.xml')->status_is(200);
    my ( $feeds, $err, $code ) = $t->app->find_feeds('/atom.xml');
    is( $code, 200 );
    ok( not defined($err) );
    is( ref $feeds->[0],      'HASH' );
    like( $feeds->[0]{xmlUrl},  qr{http://localhost:\d+/atom.xml$} ); # abs url!
    like( $feeds->[0]{htmlUrl}, qr{http://localhost/weblog/$} ); # abs url!
    is( $feeds->[0]{title},   'First Weblog' ); # title is just a hint

# link
    $t->get_ok('/link1.html')->status_is(200);
    ( $feeds, $err, $code ) = $t->app->find_feeds('/link1.html');
    is( $code, 200 );
    ok( not defined($err) );
    is( ref $feeds->[0],      'HASH' );
    like( $feeds->[0]{xmlUrl},  qr{http://localhost:\d+/atom.xml$} ); # abs url!
    like( $feeds->[0]{htmlUrl}, qr{http://localhost/weblog/$} ); # abs url!
    is( $feeds->[0]{title},   'First Weblog' ); # title is just a hint

# html page with multiple feed links

$t->get_ok('/link2_multi.html')->status_is(200);
( $feeds, $err, $code ) = $t->app->find_feeds('/link2_multi.html');
is ( $code, 200 );
ok ( not defined $err );
is ( scalar @$feeds, 3, 'got 3 possible feed links');
is( $feeds->[0]{xmlUrl},  'http://www.example.com/?feed=rss2' ); # abs url!
is( $feeds->[0]{title},   'example RSS 2.0' ); # title is just a hint
is( $feeds->[1]{xmlUrl},  'http://www.example.com/?feed=rss' ); # abs url!
is( $feeds->[1]{title},   'example RSS .92' ); # title is just a hint
is( $feeds->[2]{xmlUrl},  'http://www.example.com/?feed=atom' ); # abs url!
is( $feeds->[2]{title},   'example Atom 0.3' ); # title is just a hint

# more atom
$t->get_ok('/intertwingly.atom')->status_is(200);
( $feeds, $err, $code ) = $t->app->find_feeds('/intertwingly.atom');
is( $code, 200 );
ok( not defined($err) );
is( ref $feeds->[0],      'HASH' );
is( $feeds->[0]{xmlUrl},  'http://intertwingly.net/blog/index.atom' );
is( $feeds->[0]{htmlUrl}, 'http://intertwingly.net/blog/' );
is( $feeds->[0]{title},   'Sam Ruby' ); # title is just a hint

# feed is in link:
$t->get_ok('/link3_anchor.html')->status_is(200);
( $feeds, $err, $code ) = $t->app->find_feeds('/link3_anchor.html');
is( $code, 200 );
ok( not defined($err) );
is( ref $feeds->[0],      'HASH' );
is( $feeds->[0]{xmlUrl},  'http://example.com/foo.rss' );
is( $feeds->[0]{htmlUrl}, 'http://localhost/link3_anchor.html' );
is( $feeds->[0]{title},   'here' ); # title is just a hint
is( ref $feeds->[1],      'HASH' );
is( $feeds->[1]{xmlUrl},  'http://example.com/foo.xml' );
is( $feeds->[1]{htmlUrl}, 'http://localhost/link3_anchor.html' );
is( $feeds->[1]{title},   'example' ); # title is just a hint

done_testing();
