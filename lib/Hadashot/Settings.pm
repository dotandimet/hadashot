package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';
use Hadashot::Backend;

# This action will render a template

sub import {
  my $self = shift;
  my $out;
  if (my $opml_file = $self->param('opmlfile')) {
	$out = Hadashot::Backend->parse_opml($opml_file->asset);
	$out->annotate_bidi(); # set rtl flag
     my $coll = $out->db()->collection('subs');
     for my $sub ($out->subscriptions->each) {
     my $doc = $coll->find_one({xmlUrl => $sub->{xmlUrl}});
     if ($doc) {
          print $sub->{title}, " already exists in db with id ", $doc->{_id}, "\n";
     }
     else {
      my $oid = $coll->insert($sub);
            if ($oid) {
              print $sub->{title}, " stored with id $oid\n";
            }
     }
     }
  }
  $self->render( subs => $out );
}

sub blogroll {
  my ($self) = @_;
  my $subs = Hadashot::Backend->load_subs();
  $self->render( subs => $subs , template => 'settings/import' );
}

1;