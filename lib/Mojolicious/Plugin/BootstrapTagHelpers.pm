package Mojolicious::Plugin::BootstrapTagHelpers;
use Mojo::Base 'Mojolicious::Plugin';

# we depend on TagHelpers, but they should be there, right?
sub register {
    my ( $self, $app ) = @_;
    $app->helper(
        modal => sub {
            my ( $self, $id, $title, $body ) = @_;
            return $self->tag(
                'div',
                class             => "modal fade",
                id                => $id,
                tabindex          => "-1",
                role              => "dialog",
                'aria-labelledby' => "${id}Label",
                'aria-hidden'     => "true",
                sub {
                    $self->tag(
                        'div',
                        class => "modal-dialog",
                        sub {
                            $self->tag(
                                'div',
                                class => "modal-content",
                                sub {
                                    $self->tag(
                                        'div',
                                        class => "modal-header",
                                        sub {
                                            $self->tag(
                                                'button',
                                                type           => "button",
                                                class          => "close",
                                                'data-dismiss' => "modal",
                                                'aria-hidden'  => "true",
                                                '×'
                                              )
                                              . $self->tag(
                                                'h4',
                                                class => "modal-title",
                                                $title
                                              );
                                        }
                                      )
                                      . $self->tag(
                                        'div',
                                        class => "modal-body",
                                        $body
                                      )
                                      . $self->tag(
                                        'div',
                                        class => "modal-footer",
																				''
                                      );
                                }
                            );
                        }
                    );
                }
            );
        }
    );
    $app->helper(
        modal_btn => sub {
            my $this     = shift;
            my $text     = shift;
            my $modal_id = shift;
            return $this->tag('a', href => '#' . $modal_id, 'data-toggle' => 'modal', $text );
        }
    );
}

1;
