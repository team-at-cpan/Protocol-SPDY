package Protocol::SPDY::Frame::Control::SYN_STREAM;
use strict;
use warnings;
use 5.010;
use parent qw(Protocol::SPDY::Frame::Control);

=head1 NAME

Protocol::SPDY::Frame::Control::SynStream - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Protocol::SPDY::Constants ':all';

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
#	say "Stream $stream_id (associated with $associated_stream_id), priority $pri, slot $slot";

	my $zlib = delete $args{zlib};
	my $out = $zlib->decompress($args{data});

	my ($count) = unpack 'N1', substr $out, 0, 4, '';
	my %header;
	for my $idx (1..$count) {
		my ($k, $v) = unpack 'N/A*N/A*', $out;
		my @v = split /\0/, $v;
#		say "$idx - $k: " . join ',', @v;
		$header{$k} = \@v;
		substr $out, 0, 8 + length($k) + length($v), '';
	}
	$class->new(
		%args,
		stream_id => $stream_id,
		associated_stream_id => $associated_stream_id,
		priority => $pri,
		slot => $slot,
		headers => \%header,
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



