package Hadashot::Feed;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON qw(bson_oid);
use Mojo::Util qw(encode);

sub river {
  my ($self) = @_;
  my $news =  $self->backend->items->find({});
  $news->sort({ published => -1});
  say " Got ", $news->count() , " items\n";
  $self->render(items => $news->all, total => $news->count());
}

sub debug {
  my ($self) = @_;
  my $item = $self->backend->items->find_one(bson_oid $self->param('_id'));
  my $ass = Mojo::Asset::Memory->new;
  $ass->add_chunk(encode 'UTF-8', $item->{'_raw'});
  my $parse;
  eval {
    $parse = $self->backend->parse_rss($ass);
  };
  if ($@) {
    $self->render( item => $item, parse => undef, error => $@ );
  }
  else {
    $self->render( item => $item, parse => @$parse, error => undef );
  }   
}


1;