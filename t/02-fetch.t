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
    my ($s, $f, $e, $c);
    my $delay = Mojo::IOLoop->delay(
      sub {
        shift;    # Mojo::IOLoop::Delay
        shift;    # Mojolicious::Controller
        ($s, $f, $e, $c) = @_;
      }
    );
    my $end = $delay->begin(0);
    $t->app->process_feeds([$sub], sub { $end->(@_); });
    return ($s, $f, $e, $c);
  }
);

$t->get_ok($sub->{xmlUrl})->status_is(200);
my ($s, $f, $e, $c) = $t->app->blocker($sub);
is(ref $s,        'HASH');
is(ref $f,        'HASH');
is($e,            undef);
is($c,            200);
is($f->{'title'}, 'First Weblog');
is($s->{'title'}, 'First Weblog', 'title taken from feed');
is(scalar @{$f->{items}}, 2);
is($f->{items}[0]{title}, 'Entry Two');

# now try to fetch it again, and see what what:
($s, $f, $e, $c) = $t->app->blocker($s);
is(ref $s, 'HASH');
is($f,     undef);
is($e,     'Not Modified');
is($c,     304);

# now let's do error tests:
($s, $f, $e, $c) = $t->app->blocker({xmlUrl => '/floo'});
is(ref $s, 'HASH');
is($f,     undef);
is($e,     'Not Found');
is($c,     404);

($s, $f, $e, $c) = $t->app->blocker({xmlUrl => '/link1.html'});
is(ref $s, 'HASH');
is($f,     undef);
is($e,     undef);
is($c,     200);


# check the processing of a set of feeds

my @set = (
  '/atom.xml', '/link1.html',    # feed will be undef
  '/nothome',                    # 404
  '/goto',                       # redirect
  '/rss10.xml', '/rss20.xml',
);

my %set_tests = (
  '/atom.xml' => sub {
    is($_[0]{title}, 'First Weblog');    # $sub is altered
  },
  '/link1.html' =>                       # feed will be undef
    sub {
    is($_[1], undef);
    },
  '/nothome' =>                          # 404
    sub {
    is($_[1], undef);
    is($_[2], 'Not Found');
    is($_[3], 404);
    },
  '/goto' =>                             # redirect
    sub {
    is(scalar @{$_[1]{items}}, 2);
    is($_[3],                  200);     # no sign of the re-direct...
    },
  '/rss10.xml' => sub {
    is(scalar @{$_[1]{items}}, 2);
    is($_[1]{title},           'First Weblog');
    is($_[0]{title},           'First Weblog');
    is($_[2],                  undef);
    is($_[3],                  200);              # no sign of the re-direct...
  },
  '/rss20.xml' => sub {
    is(scalar @{$_[1]{items}}, 2);
    is($_[1]{title},           'First Weblog');
    is($_[0]{title},           'First Weblog');
    is($_[2],                  undef);
    is($_[3],                  200);              # no sign of the re-direct...
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

