package Protocol::SPDY;
# ABSTRACT: Support for the SPDY protocol
use strict;
use warnings;
use 5.010;

our $VERSION = '0.999_001';

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
use Protocol::SPDY::Proxy;

1;

__END__

=head1 DESCRIPTION

Provides an implementation for the SPDY protocol at an abstract (in-memory buffer) level.

This module will B<not> initiate or receive any network connections on its own.

It is intended for use as a base on which to build web server/client implementations
using whichever transport mechanism is appropriate, and should support blocking or
nonblocking behaviour as required.

This means that if you want to add SPDY client or server support to your code, you'll
need a transport as well:

=over 4

=item * L<Net::Async::SPDY::Server> - serve SPDY requests using L<IO::Async>

=item * L<Net::Async::SPDY::Client> - connect to SPDY servers using L<IO::Async>
(although once this is stable support may be added to L<Net::Async::HTTP>,
see L<#74387|https://rt.cpan.org/Ticket/Display.html?id=74387> for progress on this).

=back

Eventually L<POE> or L<Reflex> implementations may arrive if someone more familiar
with those frameworks takes an interest. On the server side, it should be possible
to incorporate this as a plugin for Plack/PSGI so that any PSGI-compatible web
application can support basic SPDY requests (features that plain HTTP don't support,
such as server push or prioritisation may require PSGI extensions).

For some example client and server implementations, see the C<examples/> directory
or the L</EXAMPLES> section below.

Primary focus is on providing server-side SPDY implementation for use with
browsers such as Chrome and Firefox (at the time of writing, Firefox has had
optional support for SPDY since version 11, and IE11 is also rumoured to
provide SPDY/3 support).

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

If the browser is already connected to the server using TLS, the TLS/NPN mechanism can
be used to indicate that SPDY is available. Currently this requires openssl-1.1 or later,
although the NPN extension should be simple enough to backport if needed (see
L<http://www.ietf.org/id/draft-agl-tls-nextprotoneg-00.txt> for details). Since the
port is already connected, only the <protocol> part is required ('spdy/2' or 'spdy/3')
when sending via TLS/NPN.

This information could also be provided via the Alternate-Protocol header:

 Alternate-Protocol: 2443:spdy/2,443:npn-spdy/2,443:npn-spdy/3

=head2 PACKET SEQUENCE

Typically both sides would send a SETTINGS packet first.

This would be followed by SYN_STREAM from the client corresponding to the
initial HTTP request.

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

Simple L<IO::Async>-based server which reports the originating request:

# EXAMPLE: examples/server-async.pl

L<IO::Async>-based client for simple GET requests:

# EXAMPLE: examples/client-async.pl

Other examples are in the C<examples/> directory.

=head1 SEE ALSO

Since the protocol is still in flux, it may be advisable to keep an eye on
L<http://www.chromium.org/spdy>.

The only other implementation I've seen so far for Perl is L<Net::SPDY>, which
at the time of writing is a development release but does come with a client and
server example which should make it easy to get started with.

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2013. Licensed under the same terms as Perl itself.

