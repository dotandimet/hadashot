package Hadashot::Backend::WebResource;
use Mojo::Base '-base';
use Mojo::URL;
has [qw(href type length title)];

sub url {
	my $self = shift;
	return unless ($self->href);
	return Mojo::URL->new($self->href);
}

package Hadashot::Backend::WebText;
use Mojo::Base '-base';
has 'direction' => 'ltr';
has 'content';

sub display {
	my $self = @_;
	my ($dir, $content) = ($self->direction, $self->content);
	my $align = ($dir eq 'ltr') ? 'left' : 'right';
	return qq{<div dir="$dir" align="$align">\n$content\n</div>};
}

package Hadashot::Backend::Item;
use Mojo::Base '-base';
has [qw(
	content author 
	comments
	summary
	id
	updated
	enclosure
	commentInfo
	origin
	categories annotations related
	published
	title
)]
# reader specific?
#	isReadStateLocked crawlTimeMsec timestampUsec 


has [qw{alternate canonical}] => sub { Hadashot::Backend::WebResource->new(@_) };
has [qw{replies}] => sub { [ map { Hadashot::Backend::WebResource->new($_) } @{$_[0]} ] };
has [qw(summary content)] => sub { Hadashot::Backend::WebText->new(@_) };

1;
