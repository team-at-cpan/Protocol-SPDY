package Protocol::SPDY::Frame::Data;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame);

use Protocol::SPDY::Constants ':all';

=head2 stream_id

The stream ID for this data packet.

=cut

sub stream_id { shift->{stream_id} }

=head2 payload

The bytes comprising this data packet. Note that there are no guarantees
on boundaries: UTF-8 decoding for example could fail if this packet is
processed in isolation.

=cut

sub payload { shift->{payload} }

=head2 from_data

Generates an instance from the given data.

=cut

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($stream_id, $flags, $len, $len2) = unpack "N1C1n1c1", substr $args{data}, 0, 8, '';
	$len = ($len << 8) | $len2;
	return $class->new(
		fin       => $flags & FLAG_FIN,
		stream_id => $stream_id,
		payload   => $args{data},
	);
}

=head2 as_packet

Returns the scalar bytes representing this frame.

=cut

sub as_packet {
	my $self = shift;
	my $len = length(my $payload = $self->payload);
	my $pkt = pack 'N1C1n1C1',
		($self->is_control ? 0x80000000 : 0x00000000) | ($self->stream_id & 0x7FFFFFFF),
		($self->fin ? FLAG_FIN : 0),
		$len >> 8,
		$len & 0xFF;
	$pkt .= $payload;
	# warn "done packet: $pkt\n";
	# hexdump($pkt);
	return $pkt;
}

1;

__END__

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2013. Licensed under the same terms as Perl itself.

