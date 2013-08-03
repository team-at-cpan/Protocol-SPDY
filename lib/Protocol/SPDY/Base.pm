package Protocol::SPDY::Base;
use strict;
use warnings;
use 5.010;
use parent qw(Mixin::Event::Dispatch);

=head1 NAME

Protocol::SPDY - abstract support for the SPDY protocol

=head1 DESCRIPTION

Provides the base class for client, server and generic (proxy/analysis)
SPDY handling.

=cut

use Protocol::SPDY::Constants ':all';

=head1 METHODS

=cut

sub new {
	my $class = shift;
	bless {
		zlib => Protocol::SPDY::Compress->new,
		pending_send => [],
		@_
	}, $class
}

sub zlib { shift->{zlib} }

=head2 request_close

If we want to close, send a GOAWAY message first.

=cut

sub request_close {
	my $self = shift;
	$self->send_message(GOAWAY => );
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

=head2 check_stream_id

Check whether we have established this stream before allowing it to continue

Returns true if it's okay, false if not.

=cut

sub check_stream_id {
	my ($self, $frame) = @_;

	unless(exists $self->{stream_id}{$frame->stream_id}) {
		$self->send_frame(RST_STREAM => { code => INVALID_STREAM }) ;
		return 0;
	}

	return 1;
}

# check for SYN_REPLY

=head2 create_stream

Create a stream.

Returns the stream ID, or 0 if we can't create any more on this connection.

=cut

sub create_stream {
	my ($self, %args) = @_;
	my $id = $self->next_stream_id or return 0;
	$self->send_frame(SYN_STREAM => {
		stream_id => $id,
		unidirectional => $args{unidirectional} ? 1 : 0,
	});
	return $id;
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

=head2 packet_syn_stream

Generate a SYN_STREAM packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_syn_stream {
	my ($self, %args) = @_;
}

=head2 packet_syn_reply

Generate a SYN_REPLY packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_syn_reply {
	my ($self, %args) = @_;
}

=head2 packet_rst_stream

Generate a RST_STREAM packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_rst_stream {
	my ($self, %args) = @_;
}

=head2 packet_settings

Generate a SETTINGS packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_settings {
	my ($self, %args) = @_;
}

=head2 packet_noop

Generate a SYN_STREAM packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_noop {
	my ($self, %args) = @_;
}

=head2 packet_ping

Generate a PING packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_ping {
	my ($self, %args) = @_;
}

=head2 packet_goaway

Generate a GOAWAY packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_goaway {
	my ($self, %args) = @_;
}

=head2 packet_headers

Generate a HEADERS packet.

Takes the following options:

=over 4

=item *

=back

=cut

sub packet_headers {
	my ($self, %args) = @_;
}

sub packet_request {
	my ($self, %args) = @_;

	my $uri = $args{uri} or die "No URI provided";

	# All headers must be lowercase
	my %hdr = map { lc($_) => $args{header}{$_} } keys %{$args{header}};

	# These would be ignored anyway, drop 'em if we have 'em to save
	# some bandwidth
	delete $hdr{qw(connection keep-alive host)};

	# Apply method directly
	$hdr{method} = delete $args{method};

	# Unpack the URI
	$hdr{scheme} = $uri->scheme;
	$hdr{url} = $uri->path_query;
	$hdr{version} = $args{version} || 'HTTP/1.1';
}

=head2 parse_request

Convert an incoming HTTP-over-SPDY packet into a data structure and send appropriate event(s).

=cut

sub parse_request {
	my ($self, %args) = @_;

	my $uri = $args{uri} or die "No URI provided";

	# All headers must be lowercase
	my %hdr = map { lc($_) => $args{header}{$_} } keys %{$args{header}};

	# These would be ignored anyway, drop 'em if we have 'em to save
	# some bandwidth
	delete @hdr{qw(connection keep-alive host transfer-encoding)};

	# Apply method directly
	$hdr{method} = delete $args{method};

	# Unpack the URI
	$hdr{scheme} = $uri->scheme;
	$hdr{url} = $uri->path_query;
	$hdr{version} = $args{version} // 'HTTP/1.1';
}

=head2 packet_response

Generate a response packet.

=cut

sub packet_response {
	my ($self, %args) = @_;
	# All headers must be lowercase
	my %hdr = map { lc($_) => $args{header}{$_} } keys %{$args{header}};
	delete $hdr{qw(connection keep-alive)};
	$hdr{status} = $args{status};
	$hdr{version} = $args{version} // 'HTTP/1.1';
}

sub parse_response {
	my ($self, $pkt) = @_;

	my $hdr = $self->extract_headers_from_packet($pkt);
	unless($hdr->{status}) {
		$self->send_frame(RST_STREAM => { error => PROTOCOL_ERROR });
		return $self;
	}
}

sub send_frame {
	my $self = shift;
	my ($type, $data) = @_;
	$self->write($self->build_packet($type, $data));
	return $self;
}

sub queue_frame {
	my $self = shift;
	my $frame = shift;
	$self->write($frame->as_packet($self->zlib));
}

sub build_packet {
	my $self = shift;
	my ($type, $data) = @_;
	return Protocol::SPDY::Frame::Control->new(
		# type	=> RST_STREAM,
	);
}

sub extract_frame {
	my $self = shift;
	Protocol::SPDY::Frame->extract_frame(@_, zlib => $self->zlib);
}

sub handle_frame {
	my $self = shift;
	my $frame = shift;
	$frame->process($self);
}

sub apply_settings { say "Apply settings" }

sub add_frame {
	my $self = shift;
	my $frame = shift;
	say "Add new frame";
	my $reply = 'hello!';
	$self->queue_frame(
		Protocol::SPDY::Frame::Control::SYN_REPLY->new(
			flags => 0,
			stream_id => $frame->stream_id,
			version => 3,
			nv => [
				':status' => '200 OK',
				':version' => 'HTTP/1.1',
				'server' => 'ProtocolSPDY/0.002',
				'content-type' => 'text/plain; charset=utf-8',
				'content-length' => length($reply),
			],
		)
	);
	$self->queue_frame(
		Protocol::SPDY::Frame::Data->new(
			flags => FLAG_FIN,
			stream_id => $frame->stream_id,
			payload => $reply,
		)
	);
}

1;

=pod

=head2 extract_frame

Given a scalar reference to a byte buffer, this will extract the first frame if possible
and return the bytes if it succeeded, undef if not. No frame validation is performed: the
bytes are extracted based on the length information only.

=head2 parse_frame

Parse a frame extracted by L</extract_frame>. Returns an appropriate subclass of L<Protocol::SPDY::Frame>
if this succeeded, dies if it fails.

=head2 goaway

Requests termination of the connection.

=head2 ping

Sends a ping request. We should get a PING packet back as a high-priority reply.

=head2 settings

Send settings to the remote.

=head2 credential

Sends credential information to the remote.

=cut

