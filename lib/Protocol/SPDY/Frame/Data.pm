package Protocol::SPDY::Frame::Data;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame);

use Protocol::SPDY::Constants ':all';

=head2 stream_id

=cut

sub stream_id { shift->{stream_id} }

sub payload { shift->{payload} }

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
		($self->fin ? FLAG_FIN : 0),
		$len >> 8,
		$len & 0xFF;
	$pkt .= $payload;
	# warn "done packet: $pkt\n";
	# hexdump($pkt);
	return $pkt;
}

1;
