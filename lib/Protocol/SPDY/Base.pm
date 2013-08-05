package Protocol::SPDY::Base;
use strict;
use warnings;
use parent qw(Mixin::Event::Dispatch);

=head1 NAME

Protocol::SPDY::Base - abstract support for the SPDY protocol

=head1 DESCRIPTION

Provides the base class for client, server and generic (proxy/analysis)
SPDY handling.

=cut

use Protocol::SPDY::Constants ':all';

use List::UtilsBy qw(nsort_by);

=head1 METHODS

=cut

=head2 new

Instantiates a new SPDY-handling object. Applies any attributes
passed as named parameters.

=cut

sub new {
	my $class = shift;
	bless {
		pending_send  => [ ],
		@_
	}, $class
}

=head2 sender_zlib

The compression instance used for sending data.

=cut

sub sender_zlib { shift->{sender_zlib} ||= Protocol::SPDY::Compress->new }

=head2 receiver_zlib

Compression instance used for receiving (decompressing) data.

=cut

sub receiver_zlib { shift->{receiver_zlib} ||= Protocol::SPDY::Compress->new }

=head2 request_close

Issue a close request by sending a GOAWAY message.

=cut

sub request_close {
	my $self = shift;
	my $reason = shift || 'OK';
	$self->goaway('OK')
}

=head2 check_version

Called before we do anything with a control frame.

Returns true if it's supported, false if not.

=cut

sub check_version {
	my ($self, $frame) = @_;
	if($frame->version > MAX_SUPPORTED_VERSION) {
		# Send a reset if this was a SYN_STREAM
		$self->send_frame(RST_STREAM => {
			status => UNSUPPORTED_VERSION
		}) if $frame->type == FRAME_TYPE_BY_ID->{SYN_STREAM};
		# then bail out (we do this for any frame type
		return 0;
	}
	return 1;
}

=head2 next_stream_id

Generate the next stream ID for this connection.

Returns the next available stream ID, or 0 if we're out of available streams

=cut

sub next_stream_id {
	my $self = shift;
	# 2.3.2 - server streams are even, client streams are odd
	$self->{last_stream_id} += 2;
	return $self->{last_stream_id} if $self->{last_stream_id} <= 0x7FFFFFFF;
	return 0;
}

=head2 queue_frame

Requests sending the given C< $frame > at the earliest opportunity.

=cut

sub queue_frame {
	my $self = shift;
	my $frame = shift;
	$self->write($frame->as_packet($self->sender_zlib));
}

=head2 on_read

This is the method that an external transport would call when it has
some data received from the other side of the SPDY connection. It
expects to be called with a scalar containing bytes which can be
decoded as SPDY frames; any SSL/TLS decoding should happen before
passing data to this method.

Will call L</dispatch_frame> for any valid frames that can be
extracted from the stream.

=cut

sub on_read {
	my $self = shift;
	$self->{input_buffer} .= shift;
	my @frames;
	while(defined(my $bytes = $self->extract_frame(\($self->{input_buffer})))) {
		push @frames, $self->parse_frame($bytes);
	}
	$self->dispatch_frame($_) for $self->prioritise_incoming_frames(@frames);
}

=head2 prioritise_incoming_frames

Given a list of L<Protocol::SPDY::Frame> instances, returns them
reordered so that higher-priority items such as PING are handled
first.

Does not yet support stream priority.

=cut

sub prioritise_incoming_frames {
	my $self = shift;
	my @frames = shift;
	return nsort_by { $_->type_name eq 'PING' ? 0 : 1 } @frames;
}

=head2 dispatch_frame

Dispatches the given frame to appropriate handlers - this will
be the matching L<Protocol::SPDY::Stream> if one exists, or
internal connection state handling for GOAWAY/SETTINGS frames.

=cut

sub dispatch_frame {
	my $self = shift;
	my $frame = shift;
	# If we already have a stream for this frame, it probably
	# knows better than we do how we should be handling it
	if(my $stream = $self->related_stream($frame)) {
		$stream->handle_frame($frame);
	} else {
		# This is either a frame without a stream ID, or we don't
		# have that frame yet.
		if($frame->type_name eq 'SYN_STREAM') {
			$self->incoming_stream($frame);
		} elsif($frame->type_name eq 'PING') {
			$self->invoke_event(ping => $frame);
			# Bounce it straight back
			$self->queue_frame($frame);
		} elsif($frame->type_name eq 'SETTINGS') {
			$self->invoke_event(settings => $frame);
		} else {
			die "We do not know what to do with $frame yet";
		}
	}
}

=head2 incoming_stream

Called when a new SYN_STREAM frame is received.

=cut

sub incoming_stream {
	my $self = shift;
	my $frame = shift;
	my $stream = Protocol::SPDY::Stream->new_from_syn(
		$frame,
		connection => $self
	);
	$self->{streams}{$stream->id} = $stream;
	$self->invoke_event(stream => $stream);
	$self;
}

=head2 related_stream

Returns the L<Protocol::SPDY::Stream> matching the stream_id
for this frame (if it has one).

Will return undef if we have no stream yet or this frame
does not have a stream_id.

=cut

sub related_stream {
	my $self = shift;
	my $frame = shift;
	return undef unless my $m = $frame->can('stream_id');
	my $stream_id = $m->($frame);
	return undef unless my $stream = $self->stream_by_id($stream_id);
	return $stream;
}

sub apply_settings { }

=head2 extract_frame

Given a scalar reference to a byte buffer, this will extract the first frame if possible
and return the bytes if it succeeded, undef if not. No frame validation is performed: the
bytes are extracted based on the length information only.

=cut

sub extract_frame {
	my $self = shift;
	my $buffer = shift;
	# 2.2 Frames always have a common header which is 8 bytes in length
	return undef unless length $$buffer >= 8;

	(undef, my $len) = unpack 'N1N1', $$buffer;
	$len &= 0x00FFFFFF;
	return undef unless length($$buffer) >= (8 + $len);
	my $bytes = substr $$buffer, 0, 8 + $len, '';
	return $bytes;
}

=head2 parse_frame

Parse a frame extracted by L</extract_frame>. Returns an appropriate subclass of L<Protocol::SPDY::Frame>
if this succeeded, dies if it fails.

=cut

sub parse_frame {
	my $self = shift;
	my $pkt = shift;
	return Protocol::SPDY::Frame->parse(
		\$pkt,
		zlib => $self->receiver_zlib
	);
}

=head2 goaway

Requests termination of the connection.

=cut

sub goaway {
	my $self = shift;
	my $status = shift;

	# We accept numeric or string status codes at this level
	$status = {
		OK             => 0,
		PROTOCOL_ERROR => 1,
		INTERNAL_ERROR => 2,
	}->{$status} unless 0+$status eq $status;

	$self->queue_frame(
		Protocol::SPDY::Frame::GOAWAY->new(
			last_stream => $self->last_accepted_stream_id,
			status => $status,
		)
	);
}

=head2 ping

Sends a ping request. We should get a PING packet back as a high-priority reply.

=cut

sub ping {
	my $self = shift;
	$self->queue_frame(
		Protocol::SPDY::Frame::PING->new(
			id => $self->next_ping_id,
		)
	);
}

=head2 settings

Send settings to the remote.

=cut

sub settings {
	my $self = shift;
	$self->queue_frame(
		Protocol::SPDY::Frame::SETTINGS->new(
			id       => $self->next_ping_id,
			settings => \@_,
		)
	);
}

=head2 credential

Sends credential information to the remote.

=cut

sub credential {
	my $self = shift;
	die "Credential frames are not yet implemented";
}

=head2 version

Returns the version supported by this instance. Currently, this is
always 3.

=cut

sub version { 3 }

=head2 last_stream_id

The ID for the last stream we created.

=cut

sub last_stream_id { shift->{id} }

=head2 next_id

Next ID to use for creating a stream.

=cut

sub next_id {
	my $self = shift;
	$self->{last_stream_id} ||= 0;
	$self->{last_stream_id} += 2;
}

=head2 write

Calls the external code which is expected to handle writes.

=cut

sub write {
	my $self = shift;
	$self->{on_write}->(@_)
}

sub create_stream {
	my ($self, %args) = @_;
	my $stream = Protocol::SPDY::Stream->new(
		id => $self->next_id,
		connection => $self,
	);
	$self->{streams}{$stream->id} = $stream;
	return $stream;
}

=head2 pending_send

Returns a count of the frames that are waiting to be sent.

=cut

sub pending_send {
	scalar @{ shift->{pending_send} }
}

=head2 has_stream

Returns true if we have a stream matching the ID on the
provided L<Protocol::SPDY::Stream> instance.

=cut

sub has_stream {
	my $self = shift;
	my $stream = shift;
	return exists $self->{streams}{$stream->id} ? 1 : 0;
}

=head2 stream_by_id

Returns the L<Protocol::SPDY::Stream> matching the given ID.

=cut

sub stream_by_id {
	my $self = shift;
	my $id = shift;
	return $self->{streams}{$id}
}

1;

__END__

