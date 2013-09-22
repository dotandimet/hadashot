package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON qw(encode_int64);

# This action will render a template

sub import {
    my $self = shift;
    my (@subs, @loaded, @exist);
    if ( my $in_file = $self->param('infile') ) {
				if ($self->param('type') eq 'OPML') {
        @subs = $self->backend->parse_opml( $in_file->asset );
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
    }
    $self->redirect_to( 'settings/blogroll' );
#    $self->render( subs => [@loaded, @exist] );
}

sub blogroll {
  my ($self) = @_;
  my $subs = undef;
  $subs = $self->backend->feeds->find()->all();
	my $have_items = $self->backend->items->aggregate([ { '$group' => { '_id' => '$origin', 'items' => { '$sum' => 1 }, 'last' => { '$max' => '$published'} } } ]); 
	$self->app->log->info($self->dumper($have_items));
	my %items_per_sub = map { $_->{_id} => [ $_->{items}, $_->{last} ] } @$have_items;
	$self->app->log->info($self->dumper(\%items_per_sub));
	foreach my $s (@$subs) {
		$s->{'items'} =  $items_per_sub{$s->{xmlUrl}}[0] || 0;
		$s->{'last'}  = $items_per_sub{$s->{xmlUrl}}[1] || 0;
	}
	@$subs = sort { $b->{last} <=> $a->{last} || $b->{items} <=> $a->{items} } @$subs;
  if ($self->param('js')) {
    $self->render(json => { subs => $subs } );
  }
  else {
  $self->render( subs => $subs );
  }
}

sub fetch_subscriptions {
  my ($self) = @_;
  $self->render_later;
  my @urls = $self->param('url');
	my $subs;
	if (@urls) {
		$subs = $self->backend->feeds->find( { xmlUrl => { '$in' => \@urls } } )->all;
	}
	elsif ($self->param('all')) {
		$subs = $self->backend->feeds->find( { })->all;
	}
	else {
		$subs = $self->backend->feeds->find( { active => 1 })->all;
	}
  $self->backend->process_feeds(
		$subs, sub {
		 $self->render('text' => 'done');
     # $self->redirect_to( 'settings/blogroll' );
		});
}
1;
