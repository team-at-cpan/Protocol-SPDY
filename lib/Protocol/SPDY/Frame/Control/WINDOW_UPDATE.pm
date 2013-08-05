package Protocol::SPDY::Frame::Control::WINDOW_UPDATE;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame::Control);

=head1 NAME

Protocol::SPDY::Frame::Control::SynStream - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Protocol::SPDY::Constants ':all';

=head2 type_name

The string type for this frame ('WINDOW_UPDATE').

=cut

sub type_name { 'WINDOW_UPDATE' }

=head2 from_data

Instantiate from the given data.

=cut

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($stream_id, $associated_stream_id, $slot) = unpack "N1N1n1", substr $args{data}, 0, 10, '';
	$stream_id &= ~0x80000000;
	$associated_stream_id &= ~0x80000000;
	my $pri = ($slot & 0xE000) >> 13;
	$slot &= 0xFF;

	$class->new(
		%args,
		stream_id => $stream_id,
		associated_stream_id => $associated_stream_id,
		priority => $pri,
		slot => $slot,
	);
}

=head2 stream_id

Which stream we're updating the window for.

=cut

sub stream_id { shift->{stream_id} }

=head2 to_string

String representation, for debugging.

=cut

sub to_string {
	my $self = shift;
	$self->SUPER::to_string . ', ' . join ',', map { $_ . '=' . $self->header($_) } sort keys %{$self->{headers}};
}

1;

__END__

=head1 COMPONENTS

Further documentation can be found in the following modules:

=over 4

=item * L<Protocol::SPDY> - top-level protocol object

=item * L<Protocol::SPDY::Frame> - generic frame class

=item * L<Protocol::SPDY::Frame::Control> - specific subclass for control frames

=item * L<Protocol::SPDY::Frame::Data> - specific subclass for data frames

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2012. Licensed under the same terms as Perl itself.



