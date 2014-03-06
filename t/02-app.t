use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(slurp dumper);
use FindBin;

use Hadashot::Backend;


BEGIN {
  $ENV{'MOJO_CONFIG'} = File::Spec->catdir($FindBin::Bin, 'test.conf');
  binmode STDERR, ':utf8';
  binmode STDOUT, ':utf8';
}

my $t = Test::Mojo->new('Hadashot');
push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

$t->app->log->path(undef); # log to STDERR?
$t->app->backend->setup();
$t->app->backend->reset();

# Add Subscription:
$t->post_ok('/settings/add_subscription', form => {
  url => '/atom.xml'
})->status_is(302) # actually, it should be a redirect
  ->header_like(Location => qr{/view/feed\?src=http.*/atom\.xml});

# Add remote URL:
$t->post_ok('/settings/add_subscription', form => {
  url => 'http://corky.net'
})->status_is(302) # actually, it should be a redirect
  ->header_like(Location => qr{/view/feed\?src=http.*corky.*});

$t->post_ok('/settings/import_opml', form => { infile => { file => File::Spec->catdir($FindBin::Bin, 'sample.opml') }, type => 'OPML' })->status_is(302)->header_like(Location => qr{/settings/blogroll});
done_testing();

