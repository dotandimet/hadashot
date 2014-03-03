package Hadashot::Backend::Queue;
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Util 'monkey_patch';

has max => sub { $_[0]->ua->max_connections || 4 };
has active => sub { 0 };
has jobs => sub { [] };

has delay => sub {
  my $self = shift;
  Mojo::IOLoop->delay(
    sub {
      warn "There are still waiting jobs!" if ($self->pending > 0);
    }
  );
};
has ua => sub { Mojo::UserAgent->new()->max_redirects(5)->connect_timeout(30) };

sub pending {
  my $self = shift;
  return scalar @{$self->jobs};
};

for my $name (qw(delete get head options patch post put)) {
  monkey_patch __PACKAGE__, $name, sub {
    my $self = shift;
    my $job = { method => $name };
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    $job->{'cb'} = $cb if ($cb);
    $job->{'url'} = shift;
    $job->{'headers'} = { @_ } if (scalar @_ > 1 && @_ % 2 == 0);
    return $self->enqueue($job);
  };
}

sub enqueue {
  my $self = shift;
  # validate the job:
  my $job = shift;
  if ($job && ref $job eq 'HASH') {
    die "enqueue requires a url key in the hashref argument" unless ($job->{'url'} && Mojo::URL->new($job->{'url'}));
    die "enqueue requires a callback (cb key) in the hashref argument" unless ($job->{'cb'} && ref $job->{'cb'} eq 'CODE');
  # other valid keys: headers, data, method
  push @{$self->jobs}, $job;
  }
  return $self; # make chainable?
}

sub dequeue {
  my $self = shift;
  return shift @{$self->jobs};
}

sub process {
  my ($self) = @_;
  # we have jobs and can run them:
  while ($self->active < $self->max and my $job = $self->dequeue) {
      my ($url, $headers, $cb, $data, $method) = map { $job->{$_} } (qw(url headers cb data method));
      $method ||= 'get';
      $self->active($self->active+1);
      my $end = $self->delay->begin();
      $self->ua->$method($url => $headers => sub {
        my ($ua, $tx) = @_;
        $end->();
        $self->active($self->active-1);
        say "Active is now ", $self->active, ", pending is ", $self->pending;
        $cb->($ua, $tx, $data, $self);
        $self->process();
      });
  }
  $self->delay->wait unless(Mojo::IOLoop->is_running);
}

1;
