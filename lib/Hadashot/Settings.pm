package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';
use Hadashot::Backend;

# This action will render a template

sub import {
  my $self = shift;
  my $subs;
  if (my $opml_file = $self->param('opmlfile')) {
	$subs = Hadashot::Backend->parse_opml($opml_file->asset);
	$subs->annotate_bidi(); # set rtl flag
  }
  $self->render( subs => $subs );
}

1;
