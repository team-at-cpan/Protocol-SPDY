package Protocol::SPDY::Frame::Control::GOAWAY;
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

sub status_code {
	my $self = shift;
	return $self->{status_code} unless @_;
	$self->{status_code} = shift;
	return $self;
}

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($stream_id, $status_code) = unpack "N1N1", substr $args{data}, 0, 8, '';
	$stream_id &= ~0x80000000;
	$class->new(
		%args,
		stream_id => $stream_id,
		status_code => $status_code,
	);
}

sub status_code_as_text {
	my $self = shift;
	my $code = shift // $self->status_code;
	die "Invalid status code $code" unless exists RST_STATUS_CODE_BY_ID->{$code};
	return RST_STATUS_CODE_BY_ID->{$code};
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

	my $flags = delete $args{flags} || 0;
	die "Invalid flags: " . $flags if $flags & ~(FLAG_FIN);

	if(exists $args{fin}) {
		my $fin = delete $args{fin};
		$flags |=  FLAG_FIN if $fin;
		$flags &= ~FLAG_FIN if $fin;
	}

	$args{type} = FRAME_TYPE_BY_NAME->{'GOAWAY'};
	my $self = $class->SUPER::new(%args);
	$self->{flags} = $flags;
	$self->{stream_id} = $stream_id;
	return $self;
}

sub stream_id { shift->{stream_id} }

=head2 as_packet

Returns the packet as a byte string.

=cut

sub as_packet {
	my $self = shift;
	my $zlib = shift;
	my $payload = pack 'N1N1', $self->stream_id & 0x7FFFFFFF, $self->id;
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
	$self->SUPER::to_string . ', stream ' . $self->stream_id . ', reason ' . $self->status_code_as_text;
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



