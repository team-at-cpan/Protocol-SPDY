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
		zlib         => Protocol::SPDY::Compress->new,
		pending_send => [ ],
		@_
	}, $class
}

sub zlib { shift->{zlib} }

=head2 request_close

If we want to close, send a GOAWAY message first.

=cut

sub request_close { shift->goaway('OK') }

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

=pod

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

	(undef, my $len) = unpack 'N2', $$buffer;
	$len &= 0x00FFFFFF;
	return undef unless length $$buffer >= 8 + $len;
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
		$pkt,
		zlib => $self->zlib
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

1;

__END__

