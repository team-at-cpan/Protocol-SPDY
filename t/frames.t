use strict;
use warnings;

use Test::More tests => 1;
use Test::HexString;

use Protocol::SPDY;
use Protocol::SPDY::Constants qw(:all);

my $zlib = Protocol::SPDY::Compress->new;
{
	my $frame = new_ok('Protocol::SPDY::Frame::Control::SYN_REPLY' => [
		version => 3,
		stream_id => 1,
		nv => [
			':method' => 'GET',
		],
	]);
	my $pkt = $frame->as_packet($zlib);
	is_hexstr($pkt, 'xx');
	note(Protocol::SPDY::Frame->parse(\$pkt, zlib => $zlib));
}
