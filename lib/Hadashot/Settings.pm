package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template

sub import {
    my $self = shift;
    my @subs;
    if ( my $opml_file = $self->param('opmlfile') ) {
        @subs = $self->backend->parse_opml( $opml_file->asset );
        my (@loaded, @exist);
        for my $sub (@subs) {
            $sub->{direction} = $self->backend->get_direction($sub->{'title'}); # set rtl flag
            my $doc =
              $self->backend->feeds->find_one( { xmlUrl => $sub->{xmlUrl} } );
            if ($doc) {
                push @exist, $doc;
            }
            else {
                my $oid = $self->backend->feeds->insert($sub);
                if ($oid) {
                    print $sub->{title}, " stored with id $oid\n";
                    push @loaded, { %$sub, _id => $oid };
                }
            }
        }
    }
    $self->render( exist => \@exist, loaded => \@loaded );
}

sub blogroll {
  my ($self) = @_;
  my $subs = $self->backend->feeds->find()->all();
  $self->render( subs => $subs , template => 'settings/import' );
}

1;
