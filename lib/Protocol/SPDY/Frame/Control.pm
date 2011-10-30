package Protocol::SPDY::Frame::Control;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame);

=head1 NAME

Protocol::SPDY::Frame::Control - control frame subclass for the SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

Support for control frames. Typically you'd interact with these through the top-level
L<Protocol::SPDY> object.

Subclass of L<Protocol::SPDY::Frame>. See also L<Protocol::SPDY::Frame::Data>.

=head1 METHODS

=cut

sub control_bit { 1 }

=head2 update_frametype_bit

=cut

sub update_frametype_bit { shift->update_controltype_id }

=head2 version

=cut

sub version {
	my $self = shift;
	if(@_) {
		my $id = shift;
		$self->{version} = $id;
		$self->update_version;
		return $self;
	}
	unless(exists($self->{version})) {
		$self->{version} = unpack('n1', substr $self->packet, 0, 2) >> 1;
	}
	return $self->{version};
}

=head2 controltype

=cut

sub controltype {
	my $self = shift;
	if(@_) {
		my $id = shift;
		$self->{controltype} = $id;
		$self->update_controltype;
		return $self;
	}
	unless(exists($self->{controltype})) {
		$self->{controltype} = unpack('n1', substr $self->packet, 2, 2) >> 1;
	}
	return $self->{controltype};
}

=head2 update_stream_id

=cut

sub update_stream_id {
	my $self = shift;
	substr $self->{packet}, 0, 4, pack 'N1', (($self->is_data & 0x01) | ($self->stream_id << 1));
	return $self;
}

1;
