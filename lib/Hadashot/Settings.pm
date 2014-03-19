package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';
use Mango::BSON qw(encode_int64);

# This action will render a template

sub import_opml {
  my $self = shift;
  my (@subs, @loaded, @exist);
  if (my $in_file = $self->param('infile')) {
    if ($self->param('type') eq 'OPML') {
      @subs = $self->backend->parse_opml($in_file->asset);
      my $delay = Mojo::IOLoop->delay( sub {
        my ($delay, $err) = @_;
        print STDERR $err if ($err);
      } );
      $delay->on(finish => sub {
        $self->redirect_to('settings/blogroll');
      });
      for my $sub (@subs) {
        $self->backend->save_subscription($sub, $delay->begin(0));
      }
    }
  }

#    $self->render( subs => [@loaded, @exist] );
}

sub blogroll {
  my ($self) = @_;
  my $subs = undef;
  $subs = $self->backend->feeds->find()->all();
  my $have_items = $self->backend->items->aggregate(
    [
      {
        '$group' => {
          '_id'   => '$origin',
          'items' => {'$sum' => 1},
          'last'  => {'$max' => '$published'}
        }
      }
    ]
  );

# $self->app->log->info($self->dumper($have_items));
  my %items_per_sub
    = map { $_->{_id} => [$_->{items}, $_->{last}] } @$have_items;

# $self->app->log->info($self->dumper(\%items_per_sub));
  foreach my $s (@$subs) {
    $s->{'items'} = $items_per_sub{$s->{xmlUrl}}[0] || 0;
    $s->{'last'}  = $items_per_sub{$s->{xmlUrl}}[1] || 0;
  }
  @$subs
    = sort { $b->{last} <=> $a->{last} || $b->{items} <=> $a->{items} } @$subs;
  if ($self->param('js')) {
    $self->render(json => {subs => $subs});
  }
  else {
    $self->render(subs => $subs);
  }
}

sub fetch_subscriptions {
  my ($self) = @_;
  $self->render_later;
  my @urls = $self->param('url');
  my $subs;
  if (@urls) {
    $subs = $self->backend->feeds->find({xmlUrl => {'$in' => \@urls}})->all;
  }
  elsif ($self->param('all')) {
    $subs = $self->backend->feeds->find({})->all;
  }
  else {
    $subs = $self->backend->feeds->find({active => 1})->all;
  }
  $self->app->process_feeds(
    $subs,
    sub {
      my ($self, $sub, $feed, $code, $err) = @_;
      if (!$feed) {
        print STDERR "Problem getting feed:",
          (($code) ? "Error code $code" : ''), (($err) ? "Error $err" : '');
      }
      else {
        $self->backend->update_feed($sub, $feed);
        $self->backend->feeds->update({_id => $sub->{'_id'}}, $sub);
        $self->render('text' => 'done');
      }

      # $self->redirect_to( 'settings/blogroll' );
    }
  );
}

sub add_subscription {
  my $self = shift;
  my ($url) = $self->param('url');
  unless ($url) {
    $self->render(text => 'I require a url');
  }
  else {
    my $xmlUrl;
    $self->render_later();
    my $delay = Mojo::IOLoop->delay(
      sub {
        $self->find_feeds( $url, shift->begin(0) );
      },
      sub {
        my ($delay, @feeds) = @_;
        return $delay->pass("No feeds found for $url :(")
          unless (@feeds > 0);
        # TODO add support for multiple feeds later ...
        print STDERR ("Found feed: " . $feeds[0]);
        $delay->data(xmlUrl => $feeds[0]);
        $delay->pass(undef, @feeds);
     },
     sub {
        my ($delay, $err, $xmlUrl) = @_;
        return $delay->pass($err) unless ($xmlUrl);
        $self->backend->queue->get($xmlUrl, $delay->begin(0));
        $self->backend->queue->process();
     },
     sub {
        my ($delay, $ua, $tx) = @_;
        return $delay->pass("Fail: $ua") unless ($tx);
        my ($feed, $info) = $self->backend->process_feed($tx);
        if (!$feed) {
           return $delay->pass( "Problem parsing feed:",
              (($info->{error}) ? "Error " . $info->{error} : ''));
        }
        else { # got a feed
            my $sub = { xmlUrl => '' . $delay->data('xmlUrl'), %$info };
            $self->backend->handle_feed_update($sub, $feed, $info, $delay->begin(0)); # also does save_subscription
        }
     },
     sub {
           my ($delay, $errors) = @_;
           return $self->render(text => $errors) if ($errors);
           my $dest = $self->url_for('/view/feed')->query({src => $delay->data('xmlUrl')});
           $self->redirect_to($dest);
     } );
  }
}

sub load_and_go {
  my $self = shift;
  $self->render_later();
  my $subs = $self->backend->feeds->find({xmlUrl => $self->param('src')})->all;
  $self->process_feeds(
    $subs,
    sub {
      $self->redirect_to(
        $self->url_for('/view/feed')->query({src => $self->param('src')}));
    }
  );
}

1;
