package Protocol::SPDY::Frame::HeaderSupport;
use strict;
use warnings;

=head1 NAME

Protocol::SPDY::Frame::Control::SynStream - stream creation request packet for SPDY protocol

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Protocol::SPDY::Constants ':all';

sub header {
	my $self = shift;
	my $k = shift;
	my ($hdr) = grep $_->[0] eq $k, @{$self->{headers}};
	return undef unless $hdr;
	return join "\0", @$hdr[1..$#$hdr];
}

sub headers { shift->{headers} }

sub header_list {
	my $self = shift;
	map $_->[0], @{$self->{headers}};
}

sub header_multi {
	my $self = shift;
	@{$self->{headers}{+shift}}
}

1;

