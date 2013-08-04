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

sub is_control { 1 }
sub is_data { 0 }

sub version { die "no version for $_[0]" unless $_[0]->{version}; shift->{version} }

sub type { FRAME_TYPE_BY_NAME->{ shift->type_name } }

=head2 fin

=cut

sub uni { shift->{uni} }
sub compress { shift->{compress} }

sub as_packet {
	my $self = shift;
	my %args = @_;
	my $len = length($args{payload});
	warn "undef: " . join ',', $_ for grep !defined($self->$_), qw(version type);
	my $pkt = pack 'n1n1C1n1C1',
		($self->is_control ? 0x8000 : 0x0000) | ($self->version & 0x7FFF),
		$self->type,
		($self->fin ? FLAG_FIN : 0) | ($self->uni ? FLAG_UNI : 0) | ($self->compress ? FLAG_COMPRESS : 0),
		$len >> 8,
		$len & 0xFF;
	$pkt .= $args{payload};
	# warn "done packet: $pkt\n";
	return $pkt;
}

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

=head2 pairs_to_nv_header

Returns a name-value pair header block.

=cut

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
	my $name = exists FRAME_TYPE_BY_NAME->{$type} ? $type : FRAME_TYPE_BY_ID->{$type} or die "No class for $type";
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



