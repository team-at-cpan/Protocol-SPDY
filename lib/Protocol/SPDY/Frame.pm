package Protocol::SPDY::Frame;
use strict;
use warnings;

=head1 NAME

Protocol::SPDY::Frame - support for SPDY frames

=head1 SYNOPSIS

=head1 DESCRIPTION

Support for SPDY frames. Typically you'd interact with these through the top-level
L<Protocol::SPDY> object.

See the L<Protocol::SPDY::Frame::Control> and L<Protocol::SPDY::Frame::Data> subclasses.

=cut

use Protocol::SPDY::Constants ':all';

=head1 METHODS

=cut

=head2 flags

=cut

sub flags {
	my $self = shift;
	if(@_) {
		my $flags = shift;
		$self->{flags} = $flags;
		$self->update_flags;
		return $self;
	}
	unless(exists($self->{flags})) {
		$self->{flags} = unpack 'C1', substr $self->packet, 4, 1;
	}
	return $self->{flags};
}

=head2 flag_fin

=cut

sub flag_fin {
	my $self = shift;
	if(@_) {
		my $fin = shift;
		$self->flags($fin ? $self->{flags} | FLAG_FIN : $self->{flags} & ~FLAG_FIN);
		return $self;
	}
	$self->flags & FLAG_FIN
}

=head2 flag_compress

=cut

sub flag_compress {
	my $self = shift;
	if(@_) {
		my $comp = shift;
		$self->flags($comp ? ($self->flags | FLAG_COMPRESS) : ($self->flags & ~FLAG_COMPRESS));
		return $self;
	}
	$self->flags & FLAG_COMPRESS
}

=head2 is_control

=cut

sub is_control { !shift->is_data }

=head2 is_data

=cut

sub is_data {
	my $self = shift;
	substr($self->packet, 0, 1) & 1;
}

=head2 new

=cut

sub new {
	my $self = bless {}, shift;
	$self->{packet} = "\0" x 8;
	$self->{data} = '';
	return $self;
}

=head2 update_flags

=cut

sub update_flags {
	my $self = shift;
	substr $self->{packet}, 4, 1, pack 'C1', ($self->flags & 0xFF);
	return $self;
}

=head2 update_length

=cut

sub update_length {
	my $self = shift;
	substr $self->{packet}, 5, 3, pack 'N1', ($self->length & 0x00FFFFFF);
	return $self;
}

=head2 packet

=cut

sub packet { shift->{packet} }

=head2 length

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

1;
