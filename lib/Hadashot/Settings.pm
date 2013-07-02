package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template

sub import {
  my $self = shift;
  my $out;
  if (my $opml_file = $self->param('opmlfile')) {
	$out = $self->backend->parse_opml($opml_file->asset);
	$out->annotate_bidi(); # set rtl flag
     my $coll = $out->db()->collection('subs');
     for my $sub ($out->subscriptions->each) {
     my $doc = $self->backend->feeds->find_one({xmlUrl => $sub->{xmlUrl}});
     if ($doc) {
          print $sub->{title}, " already exists in db with id ", $doc->{_id}, "\n";
     }
     else {
      my $oid = $self->backend->feeds->insert($sub);
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
  my $subs = $self->backend->load_subs();
  $self->render( subs => $subs , template => 'settings/import' );
}

1;
