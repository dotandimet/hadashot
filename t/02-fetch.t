use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;

use Mojolicious::Lite;
plugin 'FeedReader';

get '/goto' => sub { shift->redirect_to('/atom.xml'); };
push @{app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');
my $t = Test::Mojo->new(app);

my $sub = {xmlUrl => '/atom.xml'};

# block a non-blocking thing boilerplate. Ugh.
$t->app->helper(
  blocker => sub {
    my ($self, $sub) = @_;
    my ($c, $f, $r);
    my $delay = Mojo::IOLoop->delay(
      sub {
        shift;    # Mojolicious::Controller
        ($c, $f, $r) = @_;
      }
    );
    my $end = $delay->begin(0);
    $t->app->process_feeds([$sub], sub { $end->(@_); });
    say $t->app($_) for ($f, $r);
    return ($c, $f, $r);
  }
);

$t->get_ok($sub->{xmlUrl})->status_is(200);
my ($c, $f, $r) = $t->app->blocker($sub);
isa_ok($c,        'Mojolicious::Controller');
is(ref $f,        'HASH');
say $t->app->dumper($f);
is($r->{error},            undef);
is($r->{code},            200);
is(scalar @{$f->{items}}, 2);
is($f->{items}[0]{title}, 'Entry Two');

# now try to fetch it again, and see what what:
($c, $f, $r) = $t->app->blocker($sub);
is($f,     undef);
is($r->{error},     'Not Modified');
is($r->{code},     304);

# now let's do error tests:
($c, $f, $r) = $t->app->blocker({xmlUrl => '/floo'});
isa_ok($c,        'Mojolicious::Controller');
is($f,     undef);
is($r->{error},     'Not Found');
is($r->{code},     404);

($c, $f, $r) = $t->app->blocker({xmlUrl => '/link1.html'});
isa_ok($c,        'Mojolicious::Controller');
is($f,     undef);
is($r->{error},     undef);
is($r->{code},     200);


# check the processing of a set of feeds

my @set = (
  '/atom.xml', '/link1.html',    # feed will be undef
  '/nothome',                    # 404
  '/goto',                       # redirect
  '/rss10.xml', '/rss20.xml',
);

my %set_tests = (
  '/atom.xml' => sub {
    is($_[1]{title}, 'First Weblog');    # title in feed
  },
  '/link1.html' =>                       # feed will be undef
    sub {
    is($_[1], undef);
    },
  '/nothome' =>                          # 404
    sub {
    is($_[1], undef);
    is($_[2]{error}, 'Not Found');
    is($_[2]{code}, 404);
    },
  '/goto' =>                             # redirect
    sub {
    is(scalar @{$_[1]{items}}, 2);
    is($_[2]{code},                  200);     # no sign of the re-direct...
    },
  '/rss10.xml' => sub {
    is(scalar @{$_[1]{items}}, 2);
    is($_[1]{title},           'First Weblog');
    is($_[2]{error},                  undef);
    is($_[2]{code},                  200);              # no sign of the re-direct...
  },
  '/rss20.xml' => sub {
    is(scalar @{$_[1]{items}}, 2);
    is($_[1]{title},           'First Weblog');
    is($_[2]{error},                  undef);
    is($_[2]{code},                  200);              # no sign of the re-direct...
  }
);

my @subs = map { {xmlUrl => $_} } @set;


push @subs, $sub, @subs;

$t->app->process_feeds(
  \@subs,
  sub {
    isa_ok(shift, 'Mojolicious::Controller');
    my ($sub, $feed, $err, $code) = @_;
    my $req_url = $sub->{xmlUrl};
    eval {
    if ($set_tests{$req_url}) {
      $set_tests{$req_url}->($sub, $feed, $err, $code);
    }
    }; 
    if ($@) {
      die "Something horrible: ", $@;
    }
  }
);

done_testing();

