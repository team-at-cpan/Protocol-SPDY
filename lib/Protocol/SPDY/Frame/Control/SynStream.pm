package Protocol::SPDY::Frame::Control::SYN_STREAM;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame::Control);
use Exporter qw(import);

=head1 NAME

Protocol::SPDY::Frame::Control::SYN_STREAM - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Protocol::SPDY::Constants ':all';
use constant {
	FLAG_FIN => 0x01,
	FLAG_UNIDIRECTIONAL => 0x02,
};

our @EXPORT_OK = qw(FLAG_FIN FLAG_UNIDIRECTIONAL);
our %EXPORT_TAGS = (
	all => \@EXPORT_OK
);

=head2 new

Instantiate a new SYN_STREAM frame.

=over 4

=item * flags - bitmask of FLAG_FIN and/or FLAG_UNIDIRECTIONAL

=item * unidirectional - if present will set/clear FLAG_UNIDIRECTIONAL

=item * fin - if present will set/clear FLAG_FIN

=item * stream_id - 31-bit stream identifier

=item * associated_stream_id - 31-bit stream identifier to link with this one, defaults to 0

=item * priority - 2-bit value from 0..3 indicating priority, 3 being top priority

=item * nv - name/value pairs as an arrayref

=back

=cut

sub new {
	my ($class, %args) = @_;
	my $stream_id = delete $args{stream_id};
	die "no stream_id" unless defined $stream_id;

	my $associated_stream_id = delete $args{associated_stream_id} || 0;
	my $priority = delete $args{priority} || 0;
	my $nv = delete $args{nv} || [];

	my $flags = delete $args{flags} || 0;
	die "Invalid flags: " . $flags if $flags & ~(FLAG_FIN | FLAG_UNIDIRECTIONAL);

	if(exists $args{unidirectional}) {
		my $uni = delete $args{unidirectional};
		$flags |=  FLAG_UNIDIRECTIONAL if $uni;
		$flags &= ~FLAG_UNIDIRECTIONAL if $uni;
	}
	if(exists $args{fin}) {
		my $fin = delete $args{fin};
		$flags |=  FLAG_FIN if $fin;
		$flags &= ~FLAG_FIN if $fin;
	}

	$args{type} = SYN_STREAM;
	my $self = $class->SUPER::new(%args);
	$self->{flags} = $flags;
	$self->{priority} = $priority;
	$self->{stream_id} = $stream_id;
	$self->{associated_stream_id} = $associated_stream_id;
	$self->{name_value} = $nv;
	$self->update_packet;
	return $self;
}

sub stream_id { shift->{stream_id} }
sub associated_stream_id { shift->{associated_stream_id} }
sub priority { shift->{priority} }
sub nv_headers { @{shift->{name_value}} }

=head2 nv_header_block

Returns a name-value pair header block.

=cut

sub pairs_to_nv_header {
	my $class = shift;
	my @hdr = @_;
	my $data = pack 'n1', @hdr / 2;
	$data .= pack '(n/A*)*', @hdr;
	return $data;
}

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
	my $pkt = $self->SUPER::as_packet(@_);
	$pkt .= pack 'N1N1n1',
			$self->stream_id & 0x7FFFFFFF,
			$self->associated_stream_id & 0x7FFFFFFF,
			($self->priority & 0x03) << 14;
	$pkt .= $self->nv_header_block;
	return $pkt;
}

sub update_packet {
	my $self = shift;
	$self->{length} = 10 + length $self->nv_header_block;
	$self->{packet} = $self->as_packet;
	return $self;
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



