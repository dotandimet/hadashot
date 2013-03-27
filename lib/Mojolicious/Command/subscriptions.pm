package Mojolicious::Command::subscriptions;
use Mojo::Base 'Mojolicious::Command';

use Hadashot::Backend;
use Getopt::Long;

has description => "import OPML subscriptions file\n";
has usage	=> <<"EOT";
usage: $0 subscriptions OPMLFILE -flags
Valid flags are:
	-dump (default) - print JSON dump of parsed subscriptions
	-store - save subscriptions in db
EOT

sub run {
  my ($self, @args) = @_;
  my $opml_file = shift @args;
  die $self->usage unless ($opml_file && -r $opml_file);
  my $store = undef;
  if (shift @args eq '-store') {
    print "Will store it!\n";
    $store = 1;
  }
  
  
  my $out = Hadashot::Backend->parse_opml($opml_file);
  if ($store) {  
     my $coll = $out->db()->collection('subs');
     for my $sub ($out->subscriptions->each) {
	my $oid = $coll->insert($sub);
        if ($oid) {
           print $sub->{title}, " stored with id $oid\n";
        }
     }
  }
  else {
	print Mojo::JSON->new->encode( [ $out->subscriptions()->each ] );
  } 
}


'/here/docs/home/Dropbox/dotandimet@gmail.com-takeout/Reader/subscriptions.xml'
;
