package Protocol::SPDY;
# ABSTRACT: Support for the SPDY protocol
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.001';

=head1 NAME

Protocol::SPDY - abstract support for the SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

These modules aren't much use on their own, since they only deal with the abstract
protocol. If you want to add SPDY client or server support to your code, you'll need
a transport as well - try one of these:

=over 4

=item * L<Net::Async::SPDY::Server> - serve SPDY requests using L<IO::Async>

=item * L<Net::Async::SPDY::Client> - connect to SPDY servers using L<IO::Async>
(although once this is stable support may be added to L<Net::Async::HTTP>,
see L<https://rt.cpan.org/Ticket/Display.html?id=74387> for progress on this.

=back

Eventually L<POE> or L<AnyEvent> implementations should arrive when someone more
familiar with those frameworks takes an interest.

For a simple blocking client and server implementation, see the examples/ directory.

=head1 IMPLEMENTATION CONSIDERATIONS

The information in L<http://www.chromium.org/spdy> may be useful when implementing clients
(browsers).

This abstract protocol class requires a transport implementation.

=head2 UPGRADING EXISTING HTTP OR HTTPS CONNECTIONS

You can inform a browser that SPDY is available through the Alternate-Protocol HTTP
header:

 Alternate-Protocol: <port>:<protocol>

For example:

 Alternate-Protocol: 2443:spdy/2

This applies both to HTTP and HTTPS.

If the browser is already connected to the server using TLS, the TLS/NPN mechanism can be used
to indicate that SPDY is available. Currently this requires openssl-1.1 or later,
although the NPN extension should be simple enough to backport if needed (see
L<http://www.ietf.org/id/draft-agl-tls-nextprotoneg-00.txt> for details). Since the
port is already connected, only the <protocol> part is required ('spdy/2' or 'spdy/3')
when sending via TLS/NPN.

This information could also be provided via the Alternate-Protocol header:

 Alternate-Protocol: 2443:spdy/2,443:npn-spdy/2,443:npn-spdy/3

=cut

# Pull in all the required pieces
use Protocol::SPDY::Frame;
use Protocol::SPDY::Frame::Control;
use Protocol::SPDY::Frame::Data;

use Protocol::SPDY::Constants ':all';;

=head1 METHODS

=cut

=head2 request_close

If we want to close, send a GOAWAY message first

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
		$self->send_frame(RST_STREAM => { status => UNSUPPORTED_VERSION }) if $frame->type == SYN_STREAM;
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

Returns the next available stream ID,or 0 if we're out of available streams

=cut

sub next_stream_id {
	my $self = shift;
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
	delete $hdr{qw(connection keep-alive host)};

	# Apply method directly
	$hdr{method} = delete $args{method};

	# Unpack the URI 
	$hdr{scheme} = $uri->scheme;
	$hdr{url} = $uri->path_query;
	$hdr{version} = $args{version} || 'HTTP/1.1';
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
	$hdr{version} = $args{version} || 'HTTP/1.1';
}

sub parse_response {
	my ($self, $pkt) = @_;

	my $hdr = $self->extract_headers_from_packet($pkt);
	unless($hdr->{status}) {
		$self->send_frame(RST_STREAM => { error => 'PROTOCOL ERROR' });
		return;
	}
}

# other than that, we do nothing
1;

__END__

=head1 COMPONENTS

Further documentation can be found in the following modules:

=over 4

=item * L<Protocol::SPDY::Frame> - generic frame class

=item * L<Protocol::SPDY::Frame::Control> - specific subclass for control frames

=item * L<Protocol::SPDY::Frame::Data> - specific subclass for data frames

=back

=head1 SEE ALSO

Since the protocol is still in flux, it may be advisable to keep an eye on
L<http://www.chromium.org/spdy>.

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2012. Licensed under the same terms as Perl itself.

