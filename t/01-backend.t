use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::URL;
use Mojo::Util qw(slurp);
use FindBin;

use Hadashot::Backend;

my $bk = Hadashot::Backend->new(
  conf => {
      db_type      => 'mango',
      db_connect   => 'mongodb://localhost:27017',
      db_name      => 'hadashot_test_0001',
      db_feeds     => 'subs',
      db_items     => 'items',
      db_bookmarks => 'bookmarks',
      db_raw_feeds => 'raw_feeds',
      secret       => 'zasdcwdw2d'
  }
);

$bk->setup();

is($bk->feeds->find()->count(), 0, 'feeds collection empty');
my @subs = $bk->parse_opml("$FindBin::Bin/sample.opml");
foreach my $sub (@subs) {
  $bk->save_subscription($sub);
}


done_testing();
