package Protocol::SPDY::Client;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Base);

=head1 NAME

Protocol::SPDY::Client - client-side handling for SPDY sessions

=head1 SYNOPSIS

 use Protocol::SPDY;

=head1 DESCRIPTION

=cut

=head1 METHODS

=cut

=head2 initial_stream_id

Client streams always start at 2.

=cut

sub initial_stream_id { 1 }

1;

__END__

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2013. Licensed under the same terms as Perl itself.

