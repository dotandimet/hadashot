package Hadashot::Settings;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template

sub import_opml {
  my $self = shift;
  my (@subs, @loaded, @exist);
  if (my $in_file = $self->param('infile')) {
    if ($self->param('type') eq 'OPML') {
      @subs = $self->parse_opml($in_file->asset);
      my $delay = Mojo::IOLoop->delay( sub {
        my ($delay, $err) = @_;
        $self->app->log->error($err) if ($err);
      } );
      $delay->on(finish => sub {
        $self->redirect_to('/settings/blogroll');
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
  $self->render_later();
  my $delay = Mojo::IOLoop->delay(
    sub {
      my ($delay) = @_;
      $self->backend->feeds->find()->all($delay->begin());
      $self->backend->items->aggregate(
      [
        {
          '$group' => {
            '_id'   => '$origin',
            'items' => {'$sum' => 1},
            'last'  => {'$max' => '$published'}
          }
        }
      ])->all(
      $delay->begin()
    );
   },
   sub {
    my ($delay, $err1, $subs, $err2, $have_items) = @_;
    my %items_per_sub
      = map { $_->{_id} => [$_->{items}, $_->{last}] } @$have_items;

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
#    print STDERR "In blogroll - ", join q{,}, map { ref $_ } @_;
#    $self->render(text => 'blah!');
   } );
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
        $self->app->log->error("Problem getting feed:",
          (($code) ? "Error code $code" : ''), (($err) ? "Error $err" : ''));
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
        $self->ua()->max_redirects(3);
        $self->find_feeds( $url, shift->begin(0) );
      },
      sub {
        my ($delay, @feeds) = @_;
        $self->ua()->max_redirects(0); # reset state
        return $delay->pass("No feeds found for $url :(")
          unless (@feeds > 0);
        # TODO add support for multiple feeds later ...
        $self->app->log->info("Found feeds: " . join(q{, }, @feeds)) ;
        $delay->pass(undef, @feeds);
     },
     sub {
        my ($delay, $err, $feed_url) = @_;
        return $delay->pass($err) unless ($feed_url);
        $xmlUrl = $feed_url; # instead of using $delay->data
        $self->backend->queue->get($xmlUrl, $delay->begin(0));
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
            my $sub = { xmlUrl => '' . $xmlUrl, %$info };
            $self->backend->handle_feed_update($sub, $feed, $info, $delay->begin(0)); # also does save_subscription
        }
     },
     sub {
           my ($delay, $errors) = @_;
           return $self->render(text => $errors) if ($errors);
           my $dest = $self->url_for('/view/feed')->query({src => $xmlUrl});
#           $self->ua->max_redirects(0); # reset this, important when testing this very redirect!
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
