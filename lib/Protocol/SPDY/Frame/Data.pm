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

1;
