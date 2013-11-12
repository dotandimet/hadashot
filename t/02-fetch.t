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
        shift;    # Mojo::IOLoop::Delay
        ($c, $f, $r) = @_;
      }
    );
    my $end = $delay->begin(0);
    $t->app->process_feeds([$sub], sub { $end->(@_); });
    return ($c, $f, $r);
  }
);

$t->get_ok($sub->{xmlUrl})->status_is(200);
my ($c, $f, $r) = $t->app->blocker($sub);
isa_ok($c,        'Mojolicious::Controller');
is(ref $f,        'HASH');
is($r->{error},            undef);
is($r->{code},            200);
is(scalar @{$f->{items}}, 2);
is($f->{items}[0]{title}, 'Entry Two');

# see how not-modified will work:
($c, $f, $r) = $t->app->blocker({ xmlUrl => $sub->{xmlUrl}, %$r});
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
    is($_[0]{title}, 'First Weblog');    # title in feed
  },
  '/link1.html' =>                       # feed will be undef
    sub {
    is($_[0], undef);
    },
  '/nothome' =>                          # 404
    sub {
    is($_[0], undef);
    is($_[1]{error}, 'Not Found');
    is($_[1]{code}, 404);
    },
  '/goto' =>                             # redirect
    sub {
    is(scalar @{$_[0]{items}}, 2);
    is($_[1]{code},                  200);     # no sign of the re-direct...
    },
  '/rss10.xml' => sub {
    is(scalar @{$_[0]{items}}, 2);
    is($_[0]{title},           'First Weblog');
    is($_[1]{error},                  undef);
    is($_[1]{code},                  200);              # no sign of the re-direct...
  },
  '/rss20.xml' => sub {
    is(scalar @{$_[0]{items}}, 2);
    is($_[0]{title},           'First Weblog');
    is($_[1]{error},                  undef);
    is($_[1]{code},                  200);              # no sign of the re-direct...
  }
);

my @subs = map { {xmlUrl => $_} } @set;


push @subs, $sub, @subs;

$t->app->process_feeds(
  \@subs,
  sub {
    isa_ok(shift, 'Mojolicious::Controller');
    my ($feed, $req_info) = @_;
    my $req_url = $req_info->{url}->path;
    eval {
    if ($set_tests{$req_url}) {
      $set_tests{$req_url}->($feed, $req_info);
    }
    }; 
    if ($@) {
      die "Something horrible: ", $@;
    }
  }
);

done_testing();

