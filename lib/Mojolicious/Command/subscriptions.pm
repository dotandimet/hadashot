package Mojolicious::Command::subscriptions;
use Mojo::Base 'Mojolicious::Command';

use Hadashot::Backend;
use Getopt::Long qw(GetOptionsFromArray);

has description => "import OPML subscriptions file\n";
has usage	=> <<"EOT";
usage: $0 subscriptions OPMLFILE -flags
Valid flags are:
	-dump (default) - print JSON dump of parsed subscriptions
	-store - save subscriptions in db
  -fetch - update all subscriptions
  -active - only valid with -fetch; limits it to only valid feeds
EOT

sub run {
  my ($self, @args) = @_;
    GetOptionsFromArray \@args,
    'fetch' => \my $fetch,
    'active' => \my $active,
    'store' => \my $store,
    'dump'  => \my $dump;
  if ($fetch) {
    $active ||= undef;
    $self->app->fetch_subscriptions(($active) ? 1 : ());
  }
  else {
  my $opml_file = shift @args;
  die $self->usage if (! -r $opml_file && ($dump || $store));
  
  my @subs = $self->app->backend->parse_opml($opml_file) if (-r $opml_file);
  if (@subs) {
     for my $sub (@subs) {
     if ($store) {
       $self->app->backend->save_subscription($sub);
     }
     if ($dump) {
       say Mojo::JSON->new->encode($sub);
     }
    }
     }
     }
}


'/here/docs/home/Dropbox/dotandimet@gmail.com-takeout/Reader/subscriptions.xml'
;
