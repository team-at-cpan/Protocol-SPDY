package Protocol::SPDY::Frame;
use strict;
use warnings;

=head1 NAME

Protocol::SPDY::Frame - support for SPDY frames

=head1 DESCRIPTION

Support for SPDY frames. Typically you'd interact with these through the top-level
L<Protocol::SPDY> object.

See the L<Protocol::SPDY::Frame::Control> and L<Protocol::SPDY::Frame::Data> subclasses
for the two currently-defined frame types.

=cut

use Protocol::SPDY::Constants ':all';

=head1 METHODS

=cut

#=head2 flag_compress
#
#=cut
#
#sub flag_compress {
#	my $self = shift;
#	if(@_) {
#		my $comp = shift;
#		$self->flags($comp ? ($self->flags | FLAG_COMPRESS) : ($self->flags & ~FLAG_COMPRESS));
#		return $self;
#	}
#	$self->flags & FLAG_COMPRESS
#}

=head2 is_control

Returns true if this is a control frame. Recommended over
checking ->isa(L<Protocol::SPDY::Frame::Control>) directly.

=cut

sub is_control { !shift->is_data }

=head2 is_data

Returns true if this is a data frame. Recommended over
checking ->isa(L<Protocol::SPDY::Frame::Data>) directly.

=cut

sub is_data {
	my $self = shift;
	ord(substr($self->packet, 0, 1)) & 1;
}

=head2 new

Instantiate a new frame. Typically called as a super method
from the L<Protocol::SPDY::Frame::Control> or L<Protocol::SPDY::Frame::Data>
subclass implementation.

=cut

sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;
	$self->{type} = delete $args{type};
	$self->{packet} = "\0" x 8;
	$self->{data} = '';
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

sub type { shift->{type} }

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



