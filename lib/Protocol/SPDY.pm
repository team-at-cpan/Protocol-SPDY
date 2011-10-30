package Protocol::SPDY;
# ABSTRACT: Support for the SPDY protocol
use strict;
use warnings FATAL => 'all';

our $VERSION = '0.001';

# Pull in all the required pieces
use Protocol::SPDY::Frame;
use Protocol::SPDY::Frame::Control;
use Protocol::SPDY::Frame::Data;

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

=back

Eventually L<POE> or L<AnyEvent> implementations should arrive when someone more
familiar with those frameworks takes an interest.

For a simple blocking client and server implementation, see the examples/ directory.

=head2 IMPLEMENTATION CONSIDERATIONS FOR SERVERS

You can inform a browser that SPDY is available through the Alternate-Protocol HTTP
header:

 Alternate-Protocol: <port>:<protocol>

For example:

 Alternate-Protocol: 2443:spdy/2

If the browser is already connecting through https, the TLS/NPN mechanism can be used
to indicate that SPDY is available. Currently this requires openssl-1.1 or later,
although the NPN extension should be simple enough to backport if needed (see
L<http://www.ietf.org/id/draft-agl-tls-nextprotoneg-00.txt> for details). Since the
port is already connected, only the <protocol> part is required ('spdy/2' or 'spdy/3')
when sending via TLS/NPN. This information can also be provided via the Alternate-Protocol
header:

 Alternate-Protocol: 2443:spdy/2,443:npn-spdr/2,443:npn-spdr/3

=head1 COMPONENTS

Further documentation can be found in the following modules:

=over 4

=item * L<Protocol::SPDY::Frame> - generic frame class

=item * L<Protocol::SPDY::Frame::Control> - specific subclass for control frames

=item * L<Protocol::SPDY::Frame::Data> - specific subclass for data frames

=back

=cut

1;

__END__

=head1 SEE ALSO

Since the protocol is still in flux, it may be advisable to keep an eye on
L<http://www.chromium.org/spdy>.

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011. Licensed under the same terms as Perl itself.

