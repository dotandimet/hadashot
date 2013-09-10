package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template

sub import {
    my $self = shift;
    my (@subs, @loaded, @exist);
    if ( my $opml_file = $self->param('opmlfile') ) {
        @subs = $self->backend->parse_opml( $opml_file->asset );
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
    $self->render( subs => [@loaded, @exist] );
}

sub blogroll {
  my ($self) = @_;
  my $subs = undef;
  $subs = $self->backend->feeds->find()->all();
  if ($self->param('js')) {
    $self->render(json => { subs => $subs } );
  }
  else {
  $self->render( subs => $subs );
  }
}


1;
