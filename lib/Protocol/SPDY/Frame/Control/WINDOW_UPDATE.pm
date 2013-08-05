package Protocol::SPDY::Frame::Control::WINDOW_UPDATE;
use strict;
use warnings;
use parent qw(Protocol::SPDY::Frame::Control);

=head1 NAME

Protocol::SPDY::Frame::Control::SynStream - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Compress::Raw::Zlib qw(Z_OK WANT_GZIP_OR_ZLIB adler32);

use Protocol::SPDY::Constants ':all';

sub type_name { 'WINDOW_UPDATE' }

sub header {
	my $self = shift;
	my $hdr = $self->{headers}{+shift} or return undef;
	$hdr->[0]
}

sub header_multi {
	my $self = shift;
	@{$self->{headers}{+shift}}
}

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($stream_id, $associated_stream_id, $slot) = unpack "N1N1n1", substr $args{data}, 0, 10, '';
	$stream_id &= ~0x80000000;
	$associated_stream_id &= ~0x80000000;
	my $pri = ($slot & 0xE000) >> 13;
	$slot &= 0xFF;

	$class->new(
		%args,
		stream_id => $stream_id,
		associated_stream_id => $associated_stream_id,
		priority => $pri,
		slot => $slot,
	);
}

sub stream_id { shift->{stream_id} }

sub process {
	my $self = shift;
	my $spdy = shift;
	$spdy->add_frame($self);
}

sub to_string {
	my $self = shift;
	$self->SUPER::to_string . ', ' . join ',', map { $_ . '=' . $self->header($_) } sort keys %{$self->{headers}};
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



