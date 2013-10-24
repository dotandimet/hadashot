use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;

use Mojolicious::Lite;
plugin 'FeedReader';

push @{app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');
my $t = Test::Mojo->new(app);

my $sub = {
    xmlUrl => '/atom.xml'
 };
$t->get_ok($sub->{xmlUrl})->status_is(200);
my ($me, $s, $f, $e, $c);
my $delay = Mojo::IOLoop->delay(sub { shift; ($me, $s, $f, $e, $c) = @_; });
my $end = $delay->begin(0);
$t->app->process_feeds([$sub], sub { $end->(@_); });
is(ref $me, 'Mojolicious::Controller');
is(ref $s, 'HASH');
is(ref $f, 'HASH');
is($e, undef);
is($c, 200);
done_testing();

