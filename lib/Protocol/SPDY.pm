package Protocol::SPDY;
# ABSTRACT: Support for the SPDY protocol
use strict;
use warnings;

our $VERSION = '0.999_007';

=head1 NAME

Protocol::SPDY - abstract support for the SPDY protocol

=head1 SYNOPSIS

 use Protocol::SPDY;

=cut

# Pull in all the required pieces
use Protocol::SPDY::Constants ':all';

# Helpers
use curry;
use Future;

# Support for deflate/gzip
use Protocol::SPDY::Compress;

# Basic frame wrangling
use Protocol::SPDY::Frame;
use Protocol::SPDY::Frame::Control;
use Protocol::SPDY::Frame::Data;

# Specific frame types
use Protocol::SPDY::Frame::Control::SETTINGS;
use Protocol::SPDY::Frame::Control::SYN_STREAM;
use Protocol::SPDY::Frame::Control::SYN_REPLY;
use Protocol::SPDY::Frame::Control::RST_STREAM;
use Protocol::SPDY::Frame::Control::PING;
use Protocol::SPDY::Frame::Control::GOAWAY;
use Protocol::SPDY::Frame::Control::HEADERS;
use Protocol::SPDY::Frame::Control::WINDOW_UPDATE;
use Protocol::SPDY::Frame::Control::CREDENTIAL;

# Stream management
use Protocol::SPDY::Stream;

# Client/server logic
use Protocol::SPDY::Server;
use Protocol::SPDY::Client;
use Protocol::SPDY::Tracer;

1;

__END__

=head1 DESCRIPTION

Provides an implementation for the SPDY protocol at an abstract (in-memory buffer) level.

This module will B<not> initiate or receive any network connections on its own.

It is intended for use as a base on which to build web server/client implementations
using whichever transport mechanism is appropriate.

This means that if you want to add SPDY client or server support to your code, you'll
need a transport as well:

=over 4

=item * L<Net::Async::SPDY::Server> - serve SPDY requests using L<IO::Async>

=item * L<Net::Async::SPDY::Client> - connect to SPDY servers using L<IO::Async>
(although once this is stable support may be added to L<Net::Async::HTTP>,
see L<#74387|https://rt.cpan.org/Ticket/Display.html?id=74387> for progress on this).

=back

Eventually L<POE> or L<Reflex> implementations may arrive, if someone more familiar
with those frameworks takes an interest.

On the server side, it should be possible to incorporate this as a plugin for
Plack/PSGI so that any PSGI-compatible web application can support basic SPDY
requests. Features that plain HTTP doesn't support, such as server push or
prioritisation, may require PSGI extensions. Although I don't use PSGI myself,
I'd be happy to help add any necessary support required to allow these extra
features - the L<Web::Async> framework may be helpful as a working example for
SPDY-specific features.

Primary focus is on providing server-side SPDY implementation for use with
browsers such as Chrome and Firefox (at the time of writing, Firefox has had
optional support for SPDY since version 11, and IE11 is also rumoured to
provide SPDY/3 support). The Android browser has supported SPDY for some time (since
Android 3.0+?).

See the L</EXAMPLES> section below for some basic code examples.

=head1 IMPLEMENTATION CONSIDERATIONS

The information in L<http://www.chromium.org/spdy> may be useful when implementing clients
(browsers).

See the L</COMPONENTS> section for links to the main classes you'll be needing
if you're writing your own transport.

=head2 UPGRADING EXISTING HTTP OR HTTPS CONNECTIONS

You can inform a browser that SPDY is available through the Alternate-Protocol HTTP
header:

 Alternate-Protocol: <port>:<protocol>

For example:

 Alternate-Protocol: 2443:spdy/3

This applies both to HTTP and HTTPS.

If the browser is already connected to the server using TLS, the TLS/NPN mechanism can
be used to indicate that SPDY is available. Currently this requires openssl-1.1 or later,
although the NPN extension should be simple enough to backport if needed (see
L<http://www.ietf.org/id/draft-agl-tls-nextprotoneg-00.txt> for details). Since the
port is already connected, only the <protocol> part is required ('spdy/3')
when sending via TLS/NPN.

This information could also be provided via the Alternate-Protocol header:

 Alternate-Protocol: 2443:spdy/3,443:npn-spdy/3

=head2 PACKET SEQUENCE

=over 4

=item * Typically both sides would send a SETTINGS packet first.

=item * This would be followed by SYN_STREAM from the client corresponding to the
initial HTTP request.

=item * The server responds with SYN_REPLY containing the HTTP response headers.

=item * Either side may send data frames for active streams until the FIN
flag is set on a packet for that stream

=item * A request is complete when the stream on both sides is in FIN state.

=item * Further requests may be issued using SYN_STREAM

=item * If some time has passed since the last packet from the other side, a PING frame
may be sent to verify that the connection is still active.

=back

=head1 COMPONENTS

Further documentation can be found in the following modules:

=over 4

=item * L<Protocol::SPDY::Server> - handle the server side of the connection. This
would typically be used for incorporating SPDY support into a server.

=item * L<Protocol::SPDY::Client> - handle the client side of the connection. This
could be used for making SPDY requests as a client.

=item * L<Protocol::SPDY::Tracer> - if you want to check the packets that are being
generated, try this class for basic packet-level debugging.

=item * L<Protocol::SPDY::Stream> - handling for 'streams', which are somewhat
analogous to individual HTTP requests

=item * L<Protocol::SPDY::Frame> - generic frame class

=item * L<Protocol::SPDY::Frame::Control> - specific subclass for control frames

=item * L<Protocol::SPDY::Frame::Data> - specific subclass for data frames

=back

Each control frame type has its own class, see L<Protocol::SPDY::Frame::Control/TYPES>
for links.

=head1 EXAMPLES

SSL/TLS next protocol negotiation for SPDY/3 with HTTP/1.1 fallback:

# EXAMPLE: examples/npn.pl

Show frames (one per line) from traffic capture (note that this needs to be
post-TLS decryption, without any TCP/IP headers):

# EXAMPLE: examples/dumper.pl

Simple L<IO::Async>-based server which reports the originating request:

# EXAMPLE: examples/server-async.pl

L<IO::Async>-based client for simple GET requests:

# EXAMPLE: examples/client-async.pl

Other examples are in the C<examples/> directory.

=head1 SEE ALSO

Since the protocol is still in flux, it may be advisable to keep an eye on
L<http://www.chromium.org/spdy>. The preliminary work on HTTP/2.0 protocol
was at the time of writing also based on SPDY/3, so the IETF page is likely
to be a useful resource: L<http://tools.ietf.org/wg/httpbis/>.

The only other implementation I've seen so far for Perl is L<Net::SPDY>, which
as of 0.01_5 is still a development release but does come with a client and
server example which should make it easy to get started with.

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2013. Licensed under the same terms as Perl itself.

