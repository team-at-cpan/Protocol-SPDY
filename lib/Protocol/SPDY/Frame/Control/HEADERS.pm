package Protocol::SPDY::Frame::Control::HEADERS;
use strict;
use warnings;
use 5.010;
use parent qw(Protocol::SPDY::Frame::HeaderSupport Protocol::SPDY::Frame::Control);

=head1 NAME

Protocol::SPDY::Frame::Control::SynStream - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Compress::Raw::Zlib qw(Z_OK WANT_GZIP_OR_ZLIB adler32);

use Protocol::SPDY::Constants ':all';

sub type_name { 'HEADERS' }

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($stream_id) = unpack "N1", substr $args{data}, 0, 4, '';
	$stream_id &= ~0x80000000;

	my $zlib = delete $args{zlib};
	my $out = $zlib->decompress($args{data});
	my ($headers, $size) = $class->extract_headers($out);
	$class->new(
		%args,
		stream_id            => $stream_id,
		headers              => $headers,
	);
}

sub stream_id { shift->{stream_id} }

sub process {
	my $self = shift;
	my $spdy = shift;
	$spdy->add_frame($self);
}

sub as_packet {
	my $self = shift;
	my $zlib = shift;
	my $payload = pack 'N1', $self->stream_id & 0x7FFFFFFF;
	my $block = $self->pairs_to_nv_header(map {; $_->[0], join "\0", @{$_}[1..$#$_] } @{$self->headers});
	$payload .= $zlib->compress($block);
	return $self->SUPER::as_packet(
		payload => $payload,
	);
}

sub to_string {
	my $self = shift;
	$self->SUPER::to_string . ', ' . join ',', map { $_ . '=' . $self->header($_) } sort @{$self->{headers}};
}

1;

__END__

=head1 COMPONENTS

Further documentation can be found in the following modules:

=over 4

=item * L<Protocol::SPDY> - top-level protocol object

=item * L<Protocol::SPDY::Frame> - generic frame class

=item * L<Protocol::SPDY::Frame::Control> - specific subclass for control frames

=item * L<Protocol::SPDY::Frame::Data> - specific subclass for data frames

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2012. Licensed under the same terms as Perl itself.



