package Protocol::SPDY::Constants;
use strict;
use warnings;
use parent qw(Exporter);

=head1 NAME

Protocol::SPDY::Constants - constant definitions for the SPDY protocol

=head1 SYNOPSIS

 use Protocol::SPDY::Constants ':all';

=head1 DESCRIPTION

Provides some constants.

=cut

use constant {
	# Flag indicating whether this is the final packet in the stream
	FLAG_FIN	=> 0x01,
	# Whether compression is enabled
	FLAG_COMPRESS	=> 0x02,
	# Number of bytes in the header (common between control and data frames)
	HEADER_LENGTH	=> 8,
	# The spec requires seeding our zlib instance with a specific dictionary to get
	# better performance.
	ZLIB_DICTIONARY	=> join('', qw(
		optionsgetheadpostputdeletetraceacceptaccept-charsetaccept-encodingaccept-
		languageauthorizationexpectfromhostif-modified-sinceif-matchif-none-matchi
		f-rangeif-unmodifiedsincemax-forwardsproxy-authorizationrangerefererteuser
		-agent10010120020120220320420520630030130230330430530630740040140240340440
		5406407408409410411412413414415416417500501502503504505accept-rangesageeta
		glocationproxy-authenticatepublicretry-afterservervarywarningwww-authentic
		ateallowcontent-basecontent-encodingcache-controlconnectiondatetrailertran
		sfer-encodingupgradeviawarningcontent-languagecontent-lengthcontent-locati
		oncontent-md5content-rangecontent-typeetagexpireslast-modifiedset-cookieMo
		ndayTuesdayWednesdayThursdayFridaySaturdaySundayJanFebMarAprMayJunJulAugSe
		pOctNovDecchunkedtext/htmlimage/pngimage/jpgimage/gifapplication/xmlapplic
		ation/xhtmltext/plainpublicmax-agecharset=iso-8859-1utf-8gzipdeflateHTTP/1
		.1statusversionurl
	)),
};

our @EXPORT_OK = qw(FLAG_FIN FLAG_COMPRESS HEADER_LENGTH ZLIB_DICTIONARY);
our %EXPORT_TAGS = (
	'all'	=> \@EXPORT_OK,
);

1;

__END__

=head1 SEE ALSO

=over 4

=item * L<Protocol::SPDY>

=item * L<Protocol::SPDY::Frame>

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011. Licensed under the same terms as Perl itself.

