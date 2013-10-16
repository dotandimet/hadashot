use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use FindBin;

my $t = Test::Mojo->new('Hadashot');
push @{$t->app->static->paths}, File::Spec->catdir($FindBin::Bin, 'samples');

my @urls = 
(qw{
http://corky.net http://www.intertwingly.net/blog/ http://corky.net/dotan/ http://corky.net/dotan/feed http://intertwingly.net/blog/index.atom http://www.ursulium.com http://arcfinity.tumblr.com/ http://arcfinity.tumblr.com/rss}
);

# my internal urls - needs work
#(qw{ /intertwingly.html /dotan_blog.html /corky.net_dotan_feed.xml /intertwingly.atom /ursulium.html /arcfinity.rss /arcfinity.html });

foreach my $url (@urls) {
  $t->get_ok($url)->status_is(200);
  my ($feeds, $err, $code) = $t->app->find_feeds($url);
  say "URL: $url $code $err found ", scalar @$feeds;
  say $t->app->dumper($_) for @$feeds;
}

done_testing();
