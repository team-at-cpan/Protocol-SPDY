package Protocol::SPDY::Frame::Control;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame);

=head1 NAME

Protocol::SPDY::Frame::Control - control frame subclass for the SPDY protocol

=head1 DESCRIPTION

Support for control frames. Typically you'd interact with these through the top-level
L<Protocol::SPDY> object.

Subclass of L<Protocol::SPDY::Frame>. See also L<Protocol::SPDY::Frame::Data>.

=head2 TYPES

The following control frame types are known:

=over 4

=item * L<SYN_STREAM|Protocol::SPDY::Frame::Control::SYN_STREAM>

=item * L<RST_STREAM|Protocol::SPDY::Frame::Control::RST_STREAM>

=item * L<SYN_REPLY|Protocol::SPDY::Frame::Control::SYN_REPLY>

=item * L<HEADERS|Protocol::SPDY::Frame::Control::HEADERS>

=item * L<CREDENTIAL|Protocol::SPDY::Frame::Control::CREDENTIAL>

=item * L<GOAWAY|Protocol::SPDY::Frame::Control::GOAWAY>

=item * L<PING|Protocol::SPDY::Frame::Control::PING>

=item * L<SETTINGS|Protocol::SPDY::Frame::Control::SETTINGS>

=back

=cut


use Protocol::SPDY::Constants ':all';

=head1 METHODS

=cut

sub is_control { 1 }

sub is_data { 0 }

sub version {
	die "no version for $_[0]" unless $_[0]->{version};
	shift->{version}
}

sub type { FRAME_TYPE_BY_NAME->{ shift->type_name } }

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

Copyright Tom Molesworth 2011-2013. Licensed under the same terms as Perl itself.


