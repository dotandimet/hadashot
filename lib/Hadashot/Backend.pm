package Hadashot::Backend;
use v5.016;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::JSON;
use Mojo::Util qw(decode slurp trim);
use Mojo::IOLoop;
use Mango;
use Mango::BSON qw(bson_time);

has conf  => sub { {} };
has dbh   => sub { Mango->new($_[0]->conf->{'db_connect'}) };
has db    => sub { $_[0]->dbh->db($_[0]->conf->{'db_name'}); };
has json  => sub { Mojo::JSON->new(); };
has dom   => sub { Mojo::DOM->new(); };
has ua    => sub { Mojo::UserAgent->new(); };
has feeds => sub { $_[0]->db()->collection($_[0]->conf->{'db_feeds'}) };
has items => sub { $_[0]->db()->collection($_[0]->conf->{'db_items'}) };
has bookmarks =>
  sub { $_[0]->db()->collection($_[0]->conf->{'db_bookmarks'}) };
has log => sub { Mojo::Log->new() };

sub setup {
  my ($self) = @_;
  $self->feeds->create();
  $self->items->create();
  $self->items->ensure_index({published => -1});
  $self->items->ensure_index({origin    => 1});
}

sub reset {    # wanna drop all your data? cool.
  my ($self) = @_;
  $self->feeds->drop();
  $self->items->drop();
  $self->log->info('dropped all subs and items');
}

sub parse_opml {
  my ($self, $opml_file) = @_;
  my $opml_str = decode 'UTF-8',
    (ref $opml_file) ? $opml_file->slurp : slurp $opml_file;
  my $d = $self->dom->parse($opml_str);
  my (%subscriptions, %categories);
  for my $item ($d->find(q{outline})->each) {
    my $node = $item->attr;
    if (!defined $node->{type} || $node->{type} ne 'rss') {
      my $cat = $node->{title} || $node->{text};
      $categories{$cat} = $item->children->pluck('attr', 'xmlUrl');
    }
    else {    # file by RSS URL:
      $subscriptions{$node->{xmlUrl}} = $node;
    }
  }

  # assign categories
  for my $cat (keys %categories) {
    $self->log->debug("category $cat\n");
    for my $rss ($categories{$cat}->each) {
      $subscriptions{$rss}{'categories'} ||= [];
      push @{$subscriptions{$rss}{'categories'}}, $cat;
    }
  }
  return (values %subscriptions);
}

sub save_subscription {
  my ($self, $sub, $cb) = @_;
  unless ($sub->{xmlUrl} && $sub->{title}) {
    $self->log->warn(
      "Missing fields - will not save object" . $self->json->encode($sub));
    return;    # will not call your callback, will return undef.
  }
  my $doc;

#    $sub->{direction} = $self->get_direction( $sub->{'title'} );  # set rtl flag
  $doc = $self->feeds->find_one({xmlUrl => $sub->{xmlUrl}});
  unless ($doc) {
    my $oid = $self->feeds->insert($sub);
    if ($oid) {
      $self->log->info($sub->{title}, " stored with id $oid\n");
      $doc = {%$sub, _id => $oid};
    }
  }
  if ($cb && ref $cb eq 'CODE') {
    $cb->($doc);
  }
  else {
    return $doc;
  }
}

sub get_direction {
  my ($self, $text) = @_;

  #my $is_bidi = ($text =~ /\p{Hebrew}+/);
  return ($text =~ /\p{Bidi_Class:R}+/) ? 'rtl' : 'ltr';
}


sub update_feed {
  my ($self, $sub, $feed) = @_;

# update sub general properties
  for my $field (qw(title subtitle description htmlUrl)) {
    if ($feed->{$field}
      && (!exists $sub->{$field} || $feed->{$field} ne $sub->{$field}))
    {
      $sub->{$field} = $feed->{$field};
    }
  }
  foreach my $item (@{$feed->{'items'}}) {
    $item->{'origin'} = $sub->{xmlUrl};    # save our source feed...
         # fix relative links - because Sam Ruby is a wise-ass
    $item->{'link'} = abs_url($item->{'link'}, $item->{'origin'});
    if ($item->{'link'} =~ m/feedproxy/) {    # cleanup feedproxy links
      $self->unshorten_url(
        $item->{'link'},
        sub {
          $item->{'link'} = $self->cleanup_feedproxy($_[0]);
          $self->store_feed_item($item);
        }
      );
    }
    else {
      $self->store_feed_item($item);
    }
  }
}

sub store_feed_item {
  my ($self, $item) = @_;
  my ($link, $title, $content) = map { $item->{$_} } (qw(link title content));
  unless ($link) {
    my $identifier = substr($title . $content . $item->{'_raw'}, 0, 40);
    $self->log->info("No link for item $identifier");
  }
  else {
    $self->log->info("Saving item with $link - $title");

    # convert dates to Mongodb BSON ?
    for (qw(published updated)) {
      next unless ($item->{$_});
      $item->{$_} = bson_time $item->{$_} * 1000;
    }
    $self->items->update({link => $link}, $item, {upsert => 1});
  }
}

sub parse_json_collection {
  my ($self, $file) = @_;
  my $str   = slurp $file;
  my $obj   = $self->json->decode($str);
  my $items = delete $obj->{'items'};
  foreach my $item (@$items) {

  }
  my $props = $obj;
}

sub cleanup_reader_fields {
  my ($self, $item) = @_;

}


sub set_item_direction {
  my ($self, $item) = @_;
  for my $field (qw(content description title)) {
    if ($item->{$field}) {
      $item->{$field} = {
        dir     => $self->get_direction($item->{$field}),
        content => $item->{$field}
      };
    }
  }
  return $item;
}

# sanitize_item is a trivial method that only cleans up things that I
# noticed caused problems when displaying the feed HTML. I threw in font
# because it annoys me.
sub sanitize_item {
  my ($self, $item) = @_;
  for my $field (qw(content description title)) {
    if ($item->{$field} && $item->{$field} =~ /\<(script|base|font)/i) {
      my $dom = $self->dom->parse($item->{$field});
      $dom->find('script,base,font')
        ->each(sub { (lc($_->type) eq 'font') ? $_->strip() : $_->remove(); });
      $item->{$field} = $dom->to_xml;
    }
  }
}

sub unshorten_url {
  my $self  = shift;
  my $url   = shift;
  my $cb    = (ref $_[-1] eq 'CODE') ? pop : undef;
  my $final = $url;
  $self->ua->max_redirects(10);
  if ($cb) {    # try non-blocking
    $self->ua->head(
      $url,
      sub {
        my ($ua, $tx) = @_;
        if ($tx->success) {
          $self->log->info("Redirects " . join q{, },
            map { $_->req->url } (@{$tx->redirects}));
          $cb->($tx->req->url);
        }
        else {
          $self->log->error($tx->error);
        }
      }
    );
  }
  else {
    my $tx = $self->ua->head($url);
    return $tx->req->url;
  }
}

sub abs_url {
  my ($url, $base) = @_;
  if (!$url || !Mojo::URL->new($url)->host) {
    $url = Mojo::URL->new($base)->path($url)->to_abs->to_string;
  }
  return $url;
}

sub cleanup_feedproxy {
  my ($self, $url) = @_;
  for (qw(utm_source utm_medium utm_campaign)) {
    $url->query->remove($_);
  }
  return $url;
}

1;
