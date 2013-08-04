package Protocol::SPDY::Frame::Control::SETTINGS;
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

sub type_name { 'SETTINGS' }

sub setting {
	my $self = shift;
	my $k = shift;
	$k =~ s/^SETTINGS_//;
	my $id = SETTINGS_BY_NAME->{$k} or die "unknown setting $k";
	my ($v) = grep $_->[0] == $id, @{$self->{settings}};
	$v->[2]
}

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($count) = unpack "N1", substr $args{data}, 0, 4, '';
	my @settings;
	for my $idx (1..$count) {
		my ($flags, $id, $id2, $v) = unpack 'C1n1C1N1', substr $args{data}, 0, 8, '';
		$id = ($id << 8) | $id2;
		push @settings, [ $id, $flags, $v ];
	}
	$class->new(
		%args,
		settings => \@settings,
	);
}

sub as_packet {
	my $self = shift;
	my $zlib = shift;

	my @settings = @{$self->{settings}};
	my $payload = pack 'N1', scalar @settings;
	for my $idx (1..@settings) {
		my $item = shift @settings;
		$payload .= pack 'C1C1n1N1', $item->[1], ($item->[0] >> 16) & 0xFF, $item->[0] & 0xFFFF, $item->[2];
	}
	return $self->SUPER::as_packet(
		payload => $payload,
	);
}

sub process {
	my $self = shift;
	my $spdy = shift;

	$spdy->apply_settings($self);
}

sub to_string {
	my $self = shift;
	$self->SUPER::to_string . ', ' . join ',', map { (SETTINGS_BY_ID->{$_->[0]} or die "unknown setting $_->[0]") . '=' . $_->[2] } @{$self->{settings}};
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



