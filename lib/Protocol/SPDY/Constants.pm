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
	# Which version we support
	MAX_SUPPORTED_VERSION => 2,
# SETTINGS packet flags
	# Request to persist settings
	FLAG_SETTINGS_PERSIST_VALUE => 0x01,
	# Inform other side of previously-persisted settings
	FLAG_SETTINGS_PERSISTED => 0x02,
	# Expected upload bandwidth
	SETTINGS_UPLOAD_BANDWIDTH => 1,
	# Expected download bandwidth
	SETTINGS_DOWNLOAD_BANDWIDTH => 2,
	# How long we expect packets to take to go from here to there and back again
	SETTINGS_ROUND_TRIP_TIME => 3,
	# How many streams we want
	SETTINGS_MAX_CONCURRENT_STREAMS => 4,
	# Something to do with CWND, whatever that happens to be
	SETTINGS_CURRENT_CWND => 5,
	# Retransmission rate on downloads (percentage)
	SETTINGS_DOWNLOAD_RETRANS_RATE => 6,
	# Start with windows of this size (in bytes)
	SETTINGS_INITIAL_WINDOW_SIZE => 7,
# Other message types
	SYN_STREAM   => 1,
	SYN_REPLY    => 2,
	RST_STREAM   => 3,
	SETTINGS     => 4,
	NOOP         => 5,
	PING         => 6,
	GOAWAY       => 7,
	HEADERS      => 8,
# Status codes for RST_STREM
	PROTOCOL_ERROR => 1,
	INVALID_STREAM => 2,
	REFUSED_STREAM => 3,
	UNSUPPORTED_VERSION => 4,
	CANCEL => 5,
	INTERNAL_ERROR => 6,
	FLOW_CONTROL_ERROR => 7,
};

our @EXPORT_OK = qw(FLAG_FIN FLAG_COMPRESS HEADER_LENGTH ZLIB_DICTIONARY MAX_SUPPORTED_VERSION
SYN_STREAM SYN_REPLY RST_STREAM SETTINGS NOOP PING GOAWAY HEADERS
PROTOCOL_ERROR INVALID_STREAM REFUSED_STREAM UNSUPPORTED_VERSION
CANCEL INTERNAL_ERROR FLOW_CONTROL_ERROR
);

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

