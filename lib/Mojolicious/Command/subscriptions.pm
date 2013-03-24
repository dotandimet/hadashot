package Mojolicious::Command::subscriptions;
use Mojo::Base 'Mojolicious::Command';

use Hadashot::Backend;

has description => "import OPML subscriptions file\n";
has usage	=> "usage: $0 subscriptions OPMLFILE\n";

sub run {
  my ($self, @args) = @_;
  my $opml_file = shift @args;
  die $self->usage unless ($opml_file && -r $opml_file);
  my $out = Hadashot::Backend->parse_opml($opml_file);
  print Mojo::JSON->new->encode( [ $out->subscriptions()->each ] );
}


'/here/docs/home/Dropbox/dotandimet@gmail.com-takeout/Reader/subscriptions.xml'
;
