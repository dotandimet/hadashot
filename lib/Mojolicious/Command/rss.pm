package Mojolicious::Command::rss;
use Mojo::Base 'Mojolicious::Command';

use Hadashot;

has app => sub { Mojo::Server->new->build_app('Hadashot') };

has description => "fetch, parse and dump an rss feed";

has usage => <<"EOT";
usage: $0 rss URL OPTIONS
fetch rss feed from URL, parse and print Data::Dumper output
Valid Options:
	-last = print only dump of last parsed item
EOT

sub run {
	my ($self, @args) = @_;
	my ($url, $last_only);
	for (@args) {
		if (m/^\-last/) {
			$last_only = 1;
		}
		else {
			$url = $_;
		}
	}
	my $tx = $self->app->ua->get($url);
	if (my $res = $tx->success) {
			$self->app->backend->parse_rss( $res->content->asset,
			sub {
				my ($item) = pop;
				if ($last_only == 1) {
					say $self->app->dumper($item);
					$last_only = 2;
				}
				if (!defined $last_only) {
				say $self->app->dumper($item);
				}
			} );
		}
		else {
			say "Failed: ", $tx->error;
		}
}

1;
