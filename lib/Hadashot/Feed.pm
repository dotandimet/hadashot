package Hadashot::Feed;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON qw(bson_oid bson_time);
use Mojo::Util qw(encode);
use List::MoreUtils qw(uniq);

sub river {
  my ($self) = @_;
	$self->render_later();
	my $q = {};
	if ($self->param('src')) {
		$q->{'origin'} = $self->param('src');
	}
	if ($self->param('before')) {
		$q->{'published'} = {'$lt' => bson_time( $self->param('before') )};
	}
	if ($self->param('after')) {
		$q->{'published'} = {'$gt' => bson_time( $self->param('after') )};
	}
	if ($self->param('tag')) {
		$q->{'tags'} = { '$all' => [ $self->param('tag') ] };
	}
	$self->app->log->debug($self->dumper($q));
  my $news =  $self->backend->items->find($q);
  $news->sort({ published => -1});
	$news->limit(8);
	$news->all(sub{
			my ($cursor, $err, $docs) = @_;
			if ($err) {
  			$self->app->log->error( "Error getting items: ", $err );
				$self->render(text => ":( $err"); 
			}
			elsif (!$docs || @$docs == 0) {
				$self->render(text => "Got nothing :( = " . $self->dumper($cursor->explain()));
			}
			else {
				map { $self->backend->sanitize_item($_) } @$docs;
				my $data = { items => $docs, total => scalar @$docs };
				if ($self->param('js')) {
  				$self->render(json => $data);
				}
				else {
					$self->render(%$data);
				}
			} 
		});
}

sub debug {
    my ($self) = @_;
    my ( $ass, $item, @keys, $parse, $error );
    if ( $self->param('_id') ) {
        $item = $self->backend->items->find_one( bson_oid $self->param('_id') );
        $ass  = Mojo::Asset::Memory->new;
        $ass->add_chunk( encode 'UTF-8', $item->{'_raw'} );
    }
    elsif ( $self->param('file') ) {
        $ass  = $self->param('file')->asset;
        $item = {};
        $self->app->log->info( "File to debug is " . $self->param('file') );
        $self->app->log->debug( $ass->slurp );
    }

    my $parse;
    eval {
        $parse = $self->backend->parse_rss($ass);
        $self->app->log->debug( $self->dumper($parse) );
    };
    if ($@) {
        $self->app->log->error("Error parsing: $@");
        $error = $@;
        @keys  = ();
    }
    else {
        @keys = sort { length {$a} <=> length($b) }
          uniq( keys %$item, keys %{ $parse->[0] } );
    }
    $self->render(
        item => $item,
        parse =>
          ( ( ref $parse eq 'ARRAY' && @$parse > 0 ) ? $parse->[0] : {} ),
        error => undef,
        keys  => \@keys
    );
}


1;
