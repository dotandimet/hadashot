package Mojolicious::Command::rss;
use Mojo::Base 'Mojolicious::Command';

use Hadashot;

has app => sub { Mojo::Server->new->build_app('Hadashot') };

has description => "fetch, parse and dump an rss feed.\n";

has usage => <<"EOT";
usage: $0 rss URL 
fetch rss feed from URL, parse and print Data::Dumper output
EOT

sub run {
	my ($self, $url) = @_;
  my ($feed, $err, $code) = $self->app->parse_rss( Mojo::URL->new($url) );
  say $self->app->dumper($feed) if ($feed);
  say "Failed: $err " if ($err);
  say "Got code $code" if ($code);
}

1;
