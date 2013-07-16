package Protocol::SPDY::Frame::Control::SYN_REPLY;
use strict;
use warnings;
use 5.010;
use parent qw(Protocol::SPDY::Frame::Control);

=head1 NAME

Protocol::SPDY::Frame::Control::SynStream - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Protocol::SPDY::Constants ':all';

sub header {
	my $self = shift;
	my $hdr = $self->{headers}{+shift} or return undef;
	$hdr->[0]
}

sub header_multi {
	my $self = shift;
	@{$self->{headers}{+shift}}
}

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($stream_id) = unpack "N1", substr $args{data}, 0, 4, '';
	$stream_id &= ~0x80000000;
	say "Stream $stream_id";
	my $dict = ZLIB_DICTIONARY;
	my $data = $args{data};
	my $zlib = delete $args{zlib};
	my $out = $zlib->decompress($args{data});
#	printf "%v02x\n", $out;
	my ($count) = unpack 'N1', substr $out, 0, 4, '';
	my %header;
	for my $idx (1..$count) {
		my ($k, $v) = unpack 'N/A*N/A*', $out;
		my @v = split /\0/, $v;
#		say "$idx - $k: " . join ',', @v;
		$header{$k} = \@v;
		substr $out, 0, 8 + length($k) + length($v), '';
	}
	$class->new(
		%args,
		stream_id => $stream_id,
		headers => \%header,
	);
}

sub process {
	my $self = shift;
	my $spdy = shift;
	$spdy->add_frame($self);
}

=head2 new

Instantiate a new SYN_REPLY frame.

=over 4

=item * flags - bitmask with single value for FLAG_FIN

=item * fin - if present will set/clear FLAG_FIN

=item * stream_id - 31-bit stream identifier

=item * nv - name/value pairs as an arrayref

=back

=cut

sub new {
	my ($class, %args) = @_;
	my $stream_id = delete $args{stream_id};
	die "no stream_id" unless defined $stream_id;

	my $nv = delete $args{nv} || [];

	my $flags = delete $args{flags} || 0;
	die "Invalid flags: " . $flags if $flags & ~(FLAG_FIN);

	if(exists $args{fin}) {
		my $fin = delete $args{fin};
		$flags |=  FLAG_FIN if $fin;
		$flags &= ~FLAG_FIN if $fin;
	}

	$args{type} = FRAME_TYPE_BY_NAME->{'SYN_REPLY'};
	my $self = $class->SUPER::new(%args);
	$self->{flags} = $flags;
	$self->{stream_id} = $stream_id;
	$self->{name_value} = $nv;
#	$self->update_packet;
	return $self;
}

sub stream_id { shift->{stream_id} }
sub nv_headers { @{shift->{name_value}} }

sub nv_header_block {
	my $self = shift;
	$self->{nv_header_block} = $self->pairs_to_nv_header($self->nv_headers) unless exists $self->{nv_header_block};
	return $self->{nv_header_block};
}

=head2 as_packet

Returns the packet as a byte string.

=cut

sub as_packet {
	my $self = shift;
	my $zlib = shift;
	my $payload = pack 'N1', $self->stream_id & 0x7FFFFFFF;
	$payload .= $zlib->compress($self->nv_header_block);
	return $self->SUPER::as_packet(
		payload => $payload,
	);
}

sub update_packet {
	my $self = shift;
	$self->{length} = 10 + length $self->nv_header_block;
	$self->{packet} = $self->as_packet;
	return $self;
}

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



