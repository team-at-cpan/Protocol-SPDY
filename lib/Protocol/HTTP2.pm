package Protocol::HTTP2;
use strict;
use warnings;
use parent qw(Protocol::SPDY);

=head1 NAME

Protocol::HTTP2 - support for current HTTPbis specification

=head1 SYNOPSIS

 use Protocol::HTTP2;
 Protocol::HTTP2->new(...);

=head1 DESCRIPTION

See L<Protocol::SPDY> for full details.

=cut

sub new {
	my $class = shift;
	return $class->SUPER::new(version => 'http2', @_)
}

1;

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2013-2014. Licensed under the same terms as Perl itself.

