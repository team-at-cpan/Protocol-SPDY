package Protocol::SPDY::Frame::Control::CREDENTIAL;
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

sub setting { $_[0]->{settings}{$_[1]} }

sub from_data {
	my $class = shift;
	my %args = @_;
	my ($count) = unpack "N1", substr $args{data}, 0, 4, '';
	my %settings;
	for my $idx (1..$count) {
		my ($flags, $id, $id2, $v) = unpack 'C1n1C1N1', substr $args{data}, 0, 8, '';
		$id = ($id << 8) | $id2;
		(my $label = SETTINGS_BY_ID->{$id}) =~ s/^SETTINGS_//; 
		$settings{$label} = $v;
	}
#	use Data::Dumper;
#	print Dumper(\%settings);
	$class->new(
		%args,
		settings => \%settings,
	);
}

sub process {
	my $self = shift;
	my $spdy = shift;

	$spdy->apply_settings($self);
}

sub to_string {
	my $self = shift;
	$self->SUPER::to_string . ', ' . join ',', map { $_ . '=' . $self->setting($_) } sort keys %{$self->{settings}};
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



