package Protocol::SPDY::Frame::Data;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame);

=head2 stream_id

=cut

sub stream_id {
	my $self = shift;
	if(@_) {
		my $id = shift;
		$self->{stream_id} = $id;
		$self->update_stream_id;
		return $self;
	}
	unless(exists($self->{stream_id})) {
		$self->{stream_id} = unpack('N1', substr $self->packet, 0, 4) >> 1;
	}
	return $self->{stream_id};
}

=head2 update_frametype_bit

=cut

sub update_frametype_bit { shift->update_stream_id }

=head2 update_stream_id

=cut

sub update_stream_id {
	my $self = shift;
	substr $self->{packet}, 0, 4, pack 'N1', (($self->is_data & 0x01) | ($self->stream_id << 1));
	return $self;
}

sub as_packet {
	my $self = shift;
	my $base = $self->SUPER::as_packet(@_);
	my $pkt = pack 'N1N1',
			($self->is_control ? 0x8000 : 0x0000) | ($self->stream_id & 0x7FFFFFFF),
			(($self->data_flags & 0xFF) << 24) | ($self->length & 0x00FFFFFF);
	return $base . $pkt;
}

1;
