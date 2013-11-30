package Hadashot::Backend::Queue;
use Mojo::Base '-base';
use Mojo::IOLoop;
use Mojo::UserAgent;

has max => sub { $_[0]->ua->max_connections || 4 };
has active => { 0 };
has waiting => sub { [] };
has delay => sub { Mojo::IOLoop->delay() };
has ua => sub { Mojo::UserAgent->new() };

sub enqueue {
  my $self = shift;
  # validate the job:
  my $job = shift;
  if ($job && ref $job eq 'HASH') {
    die "enqueue requires a url key in the hashref argument" unless ($job->{'url'} && Mojo::URL->new($job->{'url'}));
    die "enqueue requires a callback (cb key) in the hashref argument" unless ($job->{'cb'} && ref $job->{'cb'} eq 'CODE');
  # other valid keys: headers, data
  push @{$self->waiting}, $job;
  $self->process();
  return scalar @{$self->waiting};
  }
  return;
}

sub dequeue {
  my $self = shift;
  return shift @{$self->waiting};
}

sub process {
  my ($self) = @_;
  if ($self->active < $self->max and my $job = $self->dequeue) {
      my ($url, $headers, $cb, $data) = map { $job->{$_} } (qw(url headers cb data));
      $self->active($self->active++);
      my $end = $self->delay->begin(0);
      $self->ua->get($url => $headers => sub {
        $end->();
        $self->active($self->active--);
        $cb->($ua, $tx, $data, $self);
        $self->process();
      });
  }
  $self->wait unless Mojo::IOLoop->is_running;
}

1;
