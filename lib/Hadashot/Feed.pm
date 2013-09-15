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
  my $news =  $self->backend->items->find($q);
  $news->sort({ published => -1});
	$news->limit(20);
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
				my ($ass, $item);
				if ($self->param('_id')) {
								$item = $self->backend->items->find_one(bson_oid $self->param('_id'));
								$ass = Mojo::Asset::Memory->new;
								$ass->add_chunk(encode 'UTF-8', $item->{'_raw'});
				}
				elsif ($self->param('file')) {
								$ass = $self->param('file')->asset;
				}

				my $parse;
				eval {
								$parse = $self->backend->parse_rss($ass);
				};
				if ($@) {
								$self->render( item => $item, parse => undef, error => $@ );
				}
				else {
								my @keys = sort { length{$a} <=> length($b) } uniq ( keys %$item, keys %{$parse->[0]} );
								$self->render( item => $item, parse => @$parse, error => undef, keys => \@keys );
				}
}


1;
