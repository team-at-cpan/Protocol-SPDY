package Protocol::SPDY::Frame;
use strict;
use warnings;
use 5.010;

=head1 NAME

Protocol::SPDY::Frame - support for SPDY frames

=head1 DESCRIPTION

Support for SPDY frames. Typically you'd interact with these through the top-level
L<Protocol::SPDY> object.

See the L<Protocol::SPDY::Frame::Control> and L<Protocol::SPDY::Frame::Data> subclasses
for the two currently-defined frame types.

=cut

use Encode;
use Protocol::SPDY::Constants ':all';

use overload
	'""' => 'to_string',
	bool => sub { 1 },
	fallback => 1;

=head1 METHODS

=cut

=head2 is_control

Returns true if this is a control frame. Recommended over
checking ->isa(L<Protocol::SPDY::Frame::Control>) directly.

=cut

sub is_control { !shift->is_data }

=head2 is_data

Returns true if this is a data frame. Recommended over
checking ->isa(L<Protocol::SPDY::Frame::Data>) directly.

=cut

sub is_data { shift->isa('Protocol::SPDY::Frame::Data') ? 1 : 0 }

sub fin { shift->{fin} }

=head2 new

Instantiate a new frame. Typically called as a super method
from the L<Protocol::SPDY::Frame::Control> or L<Protocol::SPDY::Frame::Data>
subclass implementation.

=cut

sub new {
	my ($class, %args) = @_;
	my $self = bless \%args, $class;
	$self->{packet} //= "\0" x 8;
	$self->{data} //= '';
	return $self;
}

=head2 update_length

Updates the length field in the packet.

=cut

sub update_length {
	my $self = shift;
	substr $self->{packet}, 5, 3, pack 'N1', ($self->length & 0x00FFFFFF);
	return $self;
}

=head2 packet

Returns the current packet as a byte string.

=cut

sub packet {
	my $self = shift;
	return $self->{packet} if exists $self->{packet};
	return $self->{packet} = $self->as_packet;
}

sub update_packet {
	my $self = shift;
	$self->{packet} = $self->as_packet;
	return $self;
}

=head2 length

Returns the length of the current packet in bytes.

=cut

sub length : method {
	my $self = shift;
	if(@_) {
		my $id = shift;
		$self->{length} = $id;
		$self->update_length;
		return $self;
	}
	unless(exists($self->{length})) {
		$self->{length} = unpack('N1', substr $self->packet, 4, 8) >> 8;
	}
	return $self->{length};
}

=head2 type

Returns the type of this frame, such as SYN_STREAM, RST_STREAM etc.

=cut

sub type { die 'abstract class, no type defined' }

sub type_string { FRAME_TYPE_BY_ID->{shift->type} }

sub as_packet { '' }

=head2 parse

Extract a frame from the given packet if possible.

=cut

sub parse {
	my $class = shift;
	my $pkt = shift;
	# 2.2 Frames always have a common header which is 8 bytes in length
	return undef unless length $$pkt >= 8;
	my ($type_bit) = unpack "C1", $$pkt;

	# Data frames technically have a different header structure, but the
	# length and control-bit values are the same.
	my ($ver, $type, $flags, $len, $len2) = unpack "n1n1c1n1c1", $$pkt;

	# 2.2.2 Length: An unsigned 24-bit value representing the number of
	# bytes after the length field... It is valid to have a zero-length data
	# frame.
	$len = ($len << 8) | $len2;
	return undef unless length $$pkt >= 8 + $len;

	my $control = $ver & 0x8000 ? 1 : 0;
	return Protocol::SPDY::Frame::Data->from_data(
		data => $$pkt
	) unless $control;

	$ver &= ~0x8000;

	my %args = @_;
	# Now we know what type we have, delegate to a subclass which knows more than
	# we do about constructing the object.
	my $target_class = $control ? 'Protocol::SPDY::Frame::Control' : 'Protocol::SPDY::Frame::Data';
	my $obj = $target_class->from_data(
		zlib    => $args{zlib},
		type    => $type,
		version => $ver,
		flags   => $flags,
		data    => substr $$pkt, 8, $len
	);
	substr $$pkt, 0, 8 + $len, '';
	$obj
}

sub flags { shift->{flags} }
sub version { shift->{version} }

sub extract_frame {
	my $class = shift;
	$class->parse(@_)
}

sub extract_headers {
	my $self = shift;
	my $data = shift;
	my $start_len = length $data;
	my ($count) = unpack 'N1', substr $data, 0, 4, '';
	my @headers;
	for my $idx (1..$count) {
		my ($k, $v) = unpack 'N/A* N/A*', $data;
		my @v = split /\0/, $v;
		# Don't allow non-ASCII characters
		push @headers, [ Encode::encode(ascii => (my $key = $k), Encode::FB_CROAK) => @v ];
		substr $data, 0, 8 + length($k) + length($v), '';
	}
	return \@headers, $start_len - length($data);
}

sub to_string {
	my $self = shift;
	'SPDY:' . $self->type_string
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



