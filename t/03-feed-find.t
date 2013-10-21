use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;

use Mojolicious::Lite;
plugin 'FeedReader';

get '/floo' => sub { shift->redirect_to('/link1.html'); };

push @{app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

my $t = Test::Mojo->new(app);

# feed
    $t->get_ok('/atom.xml')->status_is(200);
    my ( $feeds, $err, $code ) = $t->app->find_feeds('/atom.xml');
    is( $code, 200 );
    ok( not defined($err) );
    like( $feeds->[0],  qr{http://localhost:\d+/atom.xml$} ); # abs url!

# link
    $t->get_ok('/link1.html')->status_is(200);
    ( $feeds, $err, $code ) = $t->app->find_feeds('/link1.html');
    is( $code, 200 );
    ok( not defined($err) );
    like( $feeds->[0],  qr{http://localhost:\d+/atom.xml$} ); # abs url!

# html page with multiple feed links
$t->get_ok('/link2_multi.html')->status_is(200);
( $feeds, $err, $code ) = $t->app->find_feeds('/link2_multi.html');
is ( $code, 200 );
ok ( not defined $err );
is ( scalar @$feeds, 3, 'got 3 possible feed links');
is( $feeds->[0],  'http://www.example.com/?feed=rss2' ); # abs url!
is( $feeds->[1],  'http://www.example.com/?feed=rss' ); # abs url!
is( $feeds->[2],  'http://www.example.com/?feed=atom' ); # abs url!

# feed is in link:
# also, use base tag in head - for pretty url
$t->get_ok('/link3_anchor.html')->status_is(200);
( $feeds, $err, $code ) = $t->app->find_feeds('/link3_anchor.html');
is( $code, 200 );
ok( not defined($err) );
diag("Got error: $err") if ($err);
is( $feeds->[0],  'http://example.com/foo.rss' );
is( $feeds->[1],  'http://example.com/foo.xml' );

# Does it work the same non-blocking?
my $delay = Mojo::IOLoop->delay(sub{ shift; is(scalar(@_), 3); });
my $end = $delay->begin(0);
$t->app->find_feeds('/link2_multi.html', sub {
  my ($feeds, $err, $code) = @_;
  is ($code, 200 );
  ok (not defined $err);
  is( scalar @$feeds, 3);
is( $feeds->[0],  'http://www.example.com/?feed=rss2' ); # abs url!
is( $feeds->[1],  'http://www.example.com/?feed=rss' ); # abs url!
is( $feeds->[2],  'http://www.example.com/?feed=atom' ); # abs url!
  $end->(@$feeds);
});
$delay->wait();

# Let's try something with redirects:
$t->get_ok('/floo')->status_is(302);
( $feeds, $err, $code ) = $t->app->find_feeds('/floo');
is( $code, 200 ); # we follow redirects and so get only the last code
diag($err) if ($err);
ok( not defined($err) );
like( $feeds->[0],  qr{http://localhost:\d+/atom.xml$} ); # abs url!



done_testing();
