package Protocol::SPDY::Frame::Control::PING;
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

sub type_name { 'PING' }

sub id {
	my $self = shift;
	return $self->{id} unless @_;
	$self->{id} = shift;
	return $self;
}

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($id) = unpack "N1", substr $args{data}, 0, 4, '';
	$class->new(
		%args,
		id => $id,
	);
}

sub process {
	my $self = shift;
	my $spdy = shift;
	# Need to send the same frame back. We'd like this to be high priority
	# as well, but that's handled by the frame queuing logic.
	$spdy->queue_frame($self);
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
	my $id = delete $args{id};

	my $flags = delete $args{flags} || 0;
	die "Invalid flags: " . $flags if $flags;

	$args{type} = FRAME_TYPE_BY_NAME->{'PING'};
	my $self = $class->SUPER::new(%args);
	$self->{flags} = $flags;
	$self->{id} = $id;
	return $self;
}

=head2 as_packet

Returns the packet as a byte string.

=cut

sub as_packet {
	my $self = shift;
	my $payload = pack 'N1', $self->id;
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
	$self->SUPER::to_string . ', id ' . $self->id;
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



