package Protocol::SPDY::Frame::Control;
use strict;
use warnings;
use 5.010;
use parent qw(Protocol::SPDY::Frame);

=head1 NAME

Protocol::SPDY::Frame::Control - control frame subclass for the SPDY protocol

=head1 DESCRIPTION

Support for control frames. Typically you'd interact with these through the top-level
L<Protocol::SPDY> object.

Subclass of L<Protocol::SPDY::Frame>. See also L<Protocol::SPDY::Frame::Data>.

=cut


use Protocol::SPDY::Constants ':all';

=head1 METHODS

=cut

sub new {
	my ($class, %args) = @_;
	my $self = $class->SUPER::new(%args);
	return $self;
}

sub is_control { 1 }
sub is_data { 0 }

=head2 update_frametype_bit

=cut

sub update_frametype_bit { shift->update_control_type_id }

=head2 control_version

=cut

sub control_version {
	my $self = shift;
	if(@_) {
		my $id = shift;
		$self->{control_version} = $id;
		$self->update_control_version;
		return $self;
	}
	unless(exists($self->{control_version})) {
		$self->{control_version} = unpack('n1', substr $self->packet, 0, 2) >> 1;
	}
	return $self->{control_version};
}

=head2 control_type

=cut

sub control_type {
	my $self = shift;
	if(@_) {
		my $id = shift;
		$self->{control_type} = $id;
		$self->update_control_type;
		return $self;
	}
	unless(exists($self->{control_type})) {
		$self->{control_type} = unpack('n1', substr $self->packet, 2, 2) >> 1;
	}
	return $self->{control_type};
}

=head2 control_flags

=cut

sub control_flags {
	my $self = shift;
	if(@_) {
		my $flags = shift;
		$self->{control_flags} = $flags;
		$self->update_control_flags;
		return $self;
	}
	unless(exists($self->{control_flags})) {
		$self->{control_flags} = unpack 'C1', substr $self->packet, 4, 1;
	}
	return $self->{control_flags};
}

=head2 flag_fin

=cut

sub flag_fin {
	my $self = shift;
	if(@_) {
		my $fin = shift;
		my $flags = $self->control_flags;
		$self->control_flags($fin ? $flags | FLAG_FIN : $flags & ~FLAG_FIN);
		return $self;
	}
	$self->control_flags & FLAG_FIN
}

=head2 update_stream_id

=cut

sub update_stream_id {
	my $self = shift;
	substr $self->{packet}, 0, 4, pack 'N1', (($self->is_data & 0x01) | ($self->stream_id << 1));
	return $self;
}

=head2 update_control_flags

Updates the control_flags

=cut

sub update_control_flags {
	my $self = shift;
	substr $self->{packet}, 4, 1, pack 'C1', ($self->control_flags & 0xFF);
	return $self;
}

sub as_packet {
	my $self = shift;
	my %args = @_;
	my $len = length($args{payload});
	my $pkt = pack 'n1n1C1n1C1',
		($self->is_control ? 0x8000 : 0x0000) | ($self->version & 0x7FFF),
		$self->type,
		$self->flags,
		$len >> 8,
		$len & 0xFF;
	$pkt .= $args{payload};
	# warn "done packet: $pkt\n";
	return $pkt;
}

=head2 flag_compress

=cut

sub flag_compress {
	my $self = shift;
	if(@_) {
		my $comp = shift;
		my $flags = $self->control_flags;
		$self->control_flags($comp ? ($flags | FLAG_COMPRESS) : ($flags & ~FLAG_COMPRESS));
		return $self;
	}
	$self->control_flags & FLAG_COMPRESS
}


=head2 pairs_to_nv_header

Returns a name-value pair header block.

=cut

sub hexdump {
	my $idx = 0;
	my @bytes = split //, join '', @_;
	print "== had " . @bytes . " bytes\n";
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
sub pairs_to_nv_header {
	my $class = shift;
	my @hdr = @_;
	my $data = pack 'N1', @hdr / 2;
	$data .= pack '(N/A*)*', @hdr;
	return $data;
}

sub find_class_for_type {
	my $class = shift;
	my $type = shift;
	my $name = FRAME_TYPE_BY_ID->{$type} or die "No class for $type";
	return 'Protocol::SPDY::Frame::Control::' . $name;
}

sub from_data {
	my $class = shift;
	my %args = @_;
	my $flags = $args{flags};
	my $type = $args{type};
#	say "Type is " . CONTROL_FRAME_TYPES->{$type};
#	say "* FIN" if $flags & FLAG_FIN;
#	say "* UNIDIRECTIONAL" if $flags & FLAG_UNIDIRECTIONAL;
	my $target_class = $class->find_class_for_type($type);
	return $target_class->from_data(%args);
}

sub to_string {
	my $self = shift;
	$self->SUPER::to_string . ', control';
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



