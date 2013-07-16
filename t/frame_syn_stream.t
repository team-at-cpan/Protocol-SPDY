use strict;
use warnings;

use Test::More tests => 4;
use Test::Fatal;

use Protocol::SPDY::Frame::Control::SYN_STREAM;
use Protocol::SPDY::Test ':all';

ok(exception { Protocol::SPDY::Frame::Control::SYN_STREAM->new }, 'dies without stream_id');

is(
	join(
		' ',
		map sprintf('%02x', ord), split //, Protocol::SPDY::Frame::Control::SYN_STREAM->pairs_to_nv_header(
			x => 123,
			y => 'z'
		)
	),
	"00 02 00 01 78 00 03 31 32 33 00 01 79 00 01 7a",
	'nv header encoding'
);
control_frame_ok my $frame = new_ok('Protocol::SPDY::Frame::Control::SYN_STREAM' => [
	stream_id => 1,
]), { }, 'basic';
done_testing;

