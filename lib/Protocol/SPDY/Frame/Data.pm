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

sub payload { shift->{payload} }

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

sub hexdump {
	my $idx = 0;
	my @bytes = split //, join '', @_;
	print "== Data frame: had " . @bytes . " bytes\n";
	while(@bytes) {
		my @chunk = splice @bytes, 0, 16;
		printf "%04x ", $idx;
		printf "%02x ", ord $_ for @chunk;
		(my $txt = join '', @chunk) =~ s/[^[:print:]]/./g;
		print "   " x (16 - @chunk);
		print for split //, $txt;
		print "\n";
		$idx += @bytes;
	}
}
sub as_packet {
	my $self = shift;
	my $len = length(my $payload = $self->payload);
	my $pkt = pack 'N1C1n1C1',
		($self->is_control ? 0x80000000 : 0x00000000) | ($self->stream_id & 0x7FFFFFFF),
		$self->flags,
		$len >> 8,
		$len & 0xFF;
	$pkt .= $payload;
	# warn "done packet: $pkt\n";
	hexdump($pkt);
	return $pkt;
}

1;
