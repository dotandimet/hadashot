package Hadashot::Backend::Queue;
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Util 'monkey_patch';

has max => sub { $_[0]->ua->max_connections || 4 };
has active => sub { 0 };
has jobs => sub { [] };
has timer => sub { undef };
has ua => sub { Mojo::UserAgent->new()->max_redirects(5)->connect_timeout(30) };

use constant DEBUG => $ENV{HADASHOT_DEBUG} || 0;

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

sub start {
  my ($self) = @_;
  unless ($self->timer) {
    Mojo::IOLoop->start unless (Mojo::IOLoop->is_running);
    my $id = Mojo::IOLoop->recurring(3 => sub { $self->process(); });
    $self->timer($id);
  }
  return $self;
}

sub stop {
  my ($self) = @_;
  if ($self->timer) {
    Mojo::IOLoop->remove($self->timer);
    $self->timer(undef);
  }
  return $self;
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
  print STDERR "\nenqueued request for ", $job->{'url'}, "\n" if (DEBUG);
  }
  $self->start;
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
      $self->ua->$method($url => $headers => sub {
        my ($ua, $tx) = @_;
        $self->active($self->active-1);
        print STDERR "handled " . $tx->req->url,
                     , " active is now ", $self->active, ", pending is ", $self->pending , "\n"
                     if (DEBUG);
        $cb->($ua, $tx, $data, $self);
        $self->process();
      });
  }
  if ($self->pending == 0 && $self->active == 0) {
    $self->stop(); # the timer shouldn't run STAM.
  }
}

1;
