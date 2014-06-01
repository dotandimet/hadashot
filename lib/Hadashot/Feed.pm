package Hadashot::Feed;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON qw(bson_oid bson_time);
use Mojo::Util qw(encode);
use List::MoreUtils qw(uniq);

sub river {
  my ($self) = @_;
  $self->render_later();
  my $q     = {};
  my $sort  = {published => -1};
  my $limit = $self->param('max_items') || $self->config->{'max_items'} || 8;
  if ($self->param('src')) {
    $q->{'origin'} = $self->param('src');
  }
  if ($self->param('before')) {
    $q->{'published'} = {'$lt' => bson_time($self->param('before'))};
  }
  if ($self->param('after')) {
    $q->{'published'} = {'$gt' => bson_time($self->param('after'))};
    $sort = {published => 1};
  }
  if ($self->param('tag')) {
    $q->{'tags'} = {'$all' => [$self->param('tag')]};
  }
  $self->app->log->debug($self->dumper($q));
  my $news = $self->backend->items->find($q);
  $news->sort($sort);
  $news->limit($limit);
  $news->all(
    sub {
      my ($cursor, $err, $docs) = @_;
      if ($err) {
        $self->app->log->error("Error getting items: ", $err);
        $self->render(text => ":( $err");
      }
      else {
        my $data = {items => [], total => 0};
        if ($docs && @$docs > 0) {
          map { $self->backend->sanitize_item($_) } @$docs;
          map { $self->backend->set_item_direction($_) } @$docs;
          if ($sort->{'published'} == 1)
          {    # not sorted in reverse chronological order
            @$docs = sort { $b->{'published'} <=> $a->{'published'} } @$docs;
          }
          $data->{items} = $docs;
          $data->{total} = scalar @$docs;
          }
        if ($self->param('js')) {
          $self->render(json => $data);
        }
        else {
          $self->render(%$data);
        }
      }
    }
  );
}

sub debug {
  my ($self) = @_;
  my ($ass, $item, @keys, $reparse, $error);
  if ($self->param('_id')) {
    $item = $self->backend->items->find_one(bson_oid $self->param('_id'));
    $ass  = Mojo::Asset::Memory->new;
    $ass->add_chunk(encode 'UTF-8', $item->{'_raw'});
  }
  elsif ($self->param('file')) {
    $ass  = $self->param('file')->asset;
    $item = {};
    $self->app->log->info("File to debug is " . $self->param('file'));
    $self->app->log->debug($ass->slurp);
  }

  eval {
    my $parse = $self->parse_rss($ass);
    $self->app->log->debug($self->dumper($parse));
    $reparse = $parse->{'items'}[0];
  };
  if ($@) {
    $self->app->log->error("Error parsing: $@");
    $error   = $@;
    @keys    = ();
    $reparse = {};
  }
  else {
    @keys = sort { length $a <=> length $b } uniq(keys %$item, keys %$reparse);
  }
  $self->render(
    item  => $item,
    parse => $reparse,
    error => undef,
    keys  => \@keys
  );
}


1;
