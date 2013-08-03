package Protocol::SPDY::Compress;
use strict;
use warnings;
use Compress::Raw::Zlib qw(Z_OK Z_SYNC_FLUSH WANT_GZIP_OR_ZLIB);
use Protocol::SPDY::Constants ':all';

sub new { my $class = shift; bless { }, $class }

sub inflater {
	my $self = shift;
	return $self->{inflater} if $self->{inflater};
	my ($d, $status) = Compress::Raw::Zlib::Inflate->new(
		-WindowBits => WANT_GZIP_OR_ZLIB,
		-Dictionary => ZLIB_DICTIONARY,
	);
	die "Zlib failure: $status" unless $d;
	$self->{inflater} = $d;
}

sub deflater {
	my $self = shift;
	return $self->{deflater} if $self->{deflater};
	my ($d, $status) = Compress::Raw::Zlib::Deflate->new(
		-WindowBits => 12,
		-Dictionary => ZLIB_DICTIONARY,
	);
	die "Zlib failure: $status" unless $d;
	$self->{deflater} = $d;
}

sub decompress {
	my $self = shift;
	my $data = shift;
	my $comp = $self->inflater;
	my $status = $comp->inflate($data => \my $out);
	die "Failed: $status" unless $status == Z_OK;
	$out;
}

sub compress {
	my $self = shift;
	my $data = shift;
	my $comp = $self->deflater;

	my $status = $comp->deflate($data => \my $start);
	die "Failed: $status" unless $status == Z_OK;
	$status = $comp->flush(\my $extra => Z_SYNC_FLUSH);
	die "Failed: $status" unless $status == Z_OK;
	return $start . $extra;
}

1;

