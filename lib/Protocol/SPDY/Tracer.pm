package Protocol::SPDY::Tracer;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Base);

sub id { shift->{id} }

sub next_id {
	my $self = shift;
	$self->{id} ||= 0;
	$self->{id} += 2;
}

sub write { shift->{on_write}->(@_) }

sub create_stream {
	my ($self, %args) = @_;
	my $stream = Protocol::SPDY::Stream->new(
		id => $self->next_id,
		connection => $self,
	);
	$self->{streams}{$stream->id} = $stream;
	return $stream;
}

sub pending_send {
	scalar @{ shift->{pending_send} }
}

sub has_stream {
	my $self = shift;
	my $stream = shift;
	return exists $self->{streams}{$stream->id} ? 1 : 0;
}

sub control_frame_bytes {
	my $self = shift;
	my $type = shift;
	my $args = shift;
	Protocol::SPDY::Frame::Control->find_class_for_type($type)->new(
		version => $self->version,
		@$args,
	)->as_packet($self->zlib)
}

1;

