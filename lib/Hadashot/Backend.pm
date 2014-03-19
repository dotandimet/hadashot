package Hadashot::Backend;
use v5.016;
use Mojo::Base -base;
use Mojo::DOM;
use Mojo::JSON;
use Mojo::Util qw(decode slurp trim dumper);
use Mojo::IOLoop;
use Mango;
use Mango::BSON qw(bson_time bson_true);

use Mojolicious::Plugin::FeedReader;

use Hadashot::Backend::Queue;

has conf  => sub { {} };
has dbh   => sub { Mango->new($_[0]->conf->{'db_connect'}) };
has db    => sub { $_[0]->dbh->db($_[0]->conf->{'db_name'}); };
has json  => sub { Mojo::JSON->new(); };
has dom   => sub { Mojo::DOM->new(); };
has queue    => sub { Hadashot::Backend::Queue->new(); };
has feeds => sub { $_[0]->db()->collection($_[0]->conf->{'db_feeds'}) };
has items => sub { $_[0]->db()->collection($_[0]->conf->{'db_items'}) };
has bookmarks =>
  sub { $_[0]->db()->collection($_[0]->conf->{'db_bookmarks'}) };
has log => sub { Mojo::Log->new() };
has feed_reader => sub { Mojolicious::Plugin::FeedReader->new() };

# setup methods
sub collection_exists {
  my ($self, $name) = @_;
  my $coll_name = $self->conf->{$name};
  my $match = grep { $_ eq $coll_name } @{ $self->db->collection_names };
  return unless ($match);
  return 1;
}
sub setup {
  my ($self) = @_;
  $self->feeds->create() unless ($self->collection_exists('db_feeds'));
  $self->items->create() unless ($self->collection_exists('db_items'));
  $self->items->ensure_index({published => -1});
  $self->items->ensure_index({origin    => 1});
}

sub reset {    # wanna drop all your data? cool.
  my ($self) = @_;
  $self->feeds->drop() if ($self->collection_exists('db_feeds'));
  $self->items->drop() if ($self->collection_exists('db_items'));
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
  my $delay;
  unless ($cb && ref $cb eq 'CODE') {
    $delay = Mojo::IOLoop->delay(sub {
       shift;
       my ($err) = @_; 
       die "Error $err" if ($err);
       print STDERR "Saved " . $sub->{xmlUrl};
    });
    $cb = $delay->begin(0);
  };
  delete $sub->{_id}; # because Mod on _id not allowed
  $self->feeds->update(
    {xmlUrl => $sub->{xmlUrl}},
    { '$set' => $sub },
    { upsert => bson_true },
    sub {
      my ($col, $err, $doc) = @_;
      #print STDERR "updated sub - " . $sub->{xmlUrl} . ' ' . (($err) ? $err : '') . ' ' . dumper($doc);
      $cb->( (($err) ? $err : undef ) ); # notify caller of errors
   }
  );
}

sub get_direction {
  my ($self, $text) = @_;

  #my $is_bidi = ($text =~ /\p{Hebrew}+/);
  return ($text =~ /\p{Bidi_Class:R}+/) ? 'rtl' : 'ltr';
}


sub update_feed {
  my ($self, $sub, $feed, $cb) = @_;

# update sub general properties
  for my $field (qw(title subtitle description htmlUrl)) {
    if ($feed->{$field}
      && (!exists $sub->{$field} || $feed->{$field} ne $sub->{$field}))
    {
      $sub->{$field} = $feed->{$field};
    }
  }
  my $delay = Mojo::IOLoop->delay(
    sub {
      my ($delay, @args) = @_;
      foreach my $item (@{$feed->{'items'}}) {
        $item->{'origin'} = $sub->{xmlUrl};    # save our source feed...
         # fix relative links - because Sam Ruby is a wise-ass
        $item->{'link'} = Mojo::URL->new($item->{'link'})->to_abs($item->{'origin'})->to_string;
        #$self->cleanup_item_link($item, $delay->begin(0));
        $delay->pass($item);
      }
   },
    sub {
      my ($delay, @items) = (@_);
      my $now = bson_time();
      foreach my $item (@items) {
        print STDERR "Storing item... " . $item->{'link'} . '-' . $item->{'title'} if ($ENV{'HADASHOT_DEBUG'});
      # convert dates to Mongodb BSON ?
        $now = ; # decrement default "date" between items - because RSS is ordered from new to old.
        for (qw(published updated)) {
          if ($item->{$_}) {
            $item->{$_} = bson_time $item->{$_} * 1000;
          }
          else { # no date, so save when we stored it:
            $item->{$_} = $now;
          }
        }
        $self->store_feed_item($item, $delay->begin(0));
      }
    },
   sub {
      my ($delay, @args) = @_;
      unless ($delay->data('saved')) {
        $delay->data('saved' => $sub->{xmlUrl});
        print STDERR "Saved update to subscription";
        $self->save_subscription($sub, $delay->begin(0));
      }
   },
  sub {
    my ($delay, @args) = @_;
    return $cb->(@args);
  }
  );
  $delay->on('error' => sub { print STDERR "Error in update_feed:", @_; });
#  $delay->wait unless (Mojo::IOLoop->is_running);
}

sub cleanup_item_link {
  my ($self, $item, $cb) = @_;
  my $delay = Mojo::IOLoop->delay(
    sub {
      my ($delay, @args) = @_;
      return $delay->pass($item->{'link'}) if ($item->{'link'} !~ m/feedproxy/);
      $self->unshorten_url( $item->{'link'}, $delay->begin(0) );
    },
    sub {
      my ($delay, $link) = @_;
      $item->{'link'} = $self->cleanup_feedproxy($link);
      $cb->($item);
   }
  );
}

sub store_feed_item {
  my ($self, $item, $cb) = @_;
  my ($link, $title, $content) = map { $item->{$_} } (qw(link title content));
  unless ($link) {
    my $identifier = substr($title . $content . $item->{'_raw'}, 0, 40);
    return $cb->("No link for item $identifier");
  }
  else {
    $self->log->info("Saving item with $link - $title");

    $self->items->update({link => $link}, $item, {upsert => 1},
      sub {
        my ($coll, $err, $doc) = @_;
        return $cb->(($err) ? "Error in updating item: $err" : undef);
      }
    );
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
      $item->{$field} = $dom->to_string;
    }
  }
}

sub unshorten_url {
  my $self  = shift;
  my $url   = shift;
  my $cb    = (ref $_[-1] eq 'CODE') ? pop : undef;
  my $final = $url;
  $self->queue->ua->max_redirects(10);
  if ($cb) {    # try non-blocking
    $self->queue->head( # will use get; should use head
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
    my $tx = $self->queue->ua->head($url);
    return $tx->req->url;
  }
}

sub cleanup_feedproxy {
  my ($self, $url) = @_;
  $url = Mojo::URL->new($url);
  for (qw(utm_source utm_medium utm_campaign)) {
    $url->query->remove($_);
  }
  return $url->to_string();
}

sub handle_feed_update {
  my ($self, $sub, $feed, $info, $cb) = @_;
  my $delay = Mojo::IOLoop->delay(
    sub { 
      my ($delay, @args) = @_;
      $self->log->info("handle feed update finish " . dumper(\@args));
      $cb->(@args);
  });
  if ( !$feed ) {
    my $err = $info->{'error'};
    unless ($err) {
      print STDERR "No feed and no error message, ",
            dumper($info);
    }
    $self->log->warn( "Problem getting feed:",
        $sub->{xmlUrl}, $err );
    if (   $err eq 'url no longer points to a feed'
        || $err eq 'Not Found' )
    {
      $self->feeds->remove(
          { xmlUrl => $sub->{xmlUrl} },
          sub {
            my ($c, $err, $doc) = @_;
            $delay->pass(($err) ? $err : ());
            }
          );
    }
    elsif ( $err eq 'Not Modified' ) {
      $delay->pass($err);
    }
    else {
      $sub->{active} = 0;
      $sub->{error}  = $err;
      $self->save_subscription( $sub, $delay->begin(0) );
    }
  }
  else {
    $sub->{active} = 1;
    $self->update_feed( $sub, $feed, $delay->begin(0) );
  }
}

sub fetch_subscriptions {
    my ( $self, @feeds ) = @_;
    my $query;
    if (@feeds == 0) { # no feeds specified, fetch all:
      $query = ();
    }
    elsif (defined $feeds[0] && $feeds[0] eq '1') {
      $query = { "active" => 1 };
    }
    else {
      $query = {xmlUrl => {'$in' => \@feeds}};
    }
    my $delay = Mojo::IOLoop->delay(
      sub {
        my ($delay) = shift;
        $self->feeds->find($query)->all( $delay->begin(0) );
      },
      sub {
        my ($delay, $cur, $err, $subs) = @_;
        $delay->pass($err) if ($err);
        print STDERR "Will check " . scalar @$subs . " feeds";
        foreach my $sub (@$subs) {
          my $end = $delay->begin(0);
          $self->queue->get(
            $sub->{xmlUrl},
            $self->feed_reader->set_req_headers($sub),
            sub {
                my ( $ua,   $tx )   = @_;
                my ( $feed, $info ) = $self->process_feed($tx);
                $self->handle_feed_update($sub, $feed, $info, $end);
            }
          );
        };
        $self->queue->process();
    },
    sub {
      my ($delay, $err) = @_;
      print STDERR "Final step in fetch_subscriptions - did we reach it?";
      print STDERR "fetch_subscriptions failed: $err" if ($err);
      return;
    });
    $delay->wait unless Mojo::IOLoop->is_running;
}

sub process_feed {
  my ($self, $tx) = @_;
  my $req_info = $self->req_info($tx);
  my $feed;
  if (!defined $req_info->{error} && $req_info->{'code'} == 200) {
    eval { $feed = $self->feed_reader->parse_rss($tx->res->dom); };
    if ($@) { # assume no error from tx, because code is 200
      $req_info->{'error'} = $@;
    }
    if (!$feed && !defined $req_info->{'error'}) {
      $req_info->{'error'} = 'url no longer points to a feed';
    }
  }
  return ($feed, $req_info);
}

sub req_info {
  my ($tx) = pop;
  my %info = (url => $tx->req->url);
  if (my $res = $tx->success) {
    $info{'code'} = $res->code;
    if ($res->code == 200) {
      my $headers = $res->headers;
      my ($last_modified, $etag) = ($headers->last_modified, $headers->etag);
      if ($last_modified) {
        $info{last_modified} = $last_modified;
      }
      if ($etag) {
        $info{etag} = $etag;
      }
    }
    else {
      $info{'error'} = $tx->res->message; # for not modified etc.
    }
  }
  else {
    my ($err, $code) = $tx->error;
    $info{'code'} = $code if ($code);
    $info{'error'} = $err;
  }
  return \%info;
}

# set request conditional headers from saved last_modified and etag headers
sub set_req_headers {
  my $h = pop;
  my %headers;
  $headers{'If-Modified-Since'} = $h->{last_modified} if ($h->{last_modified});
  $headers{'If-None-Match'} = $h->{etag} if ($h->{etag});
  return %headers;
}

1;
