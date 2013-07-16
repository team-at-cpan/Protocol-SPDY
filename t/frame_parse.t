use strict;
use warnings;
use Test::More tests => 9;

use Protocol::SPDY::Frame::Control;
use Protocol::SPDY::Frame::Data;
use Protocol::SPDY::Frame::Control::SETTINGS;
use Protocol::SPDY::Frame::Control::SYN_STREAM;
use Protocol::SPDY::Compress;

use Protocol::SPDY::Constants qw(:all);

my $zlib = Protocol::SPDY::Compress->new;
{ # Settings frame
	my $pkt = join "", map chr hex, qw(80 03 00 04 00 00 00 14 00 00 00 02 00 00 00 04 00 00 03 e8 00 00 00 07 00 a0 00 00);
	ok(my $frame = Protocol::SPDY::Frame->parse(\$pkt, zlib => $zlib), 'parse settings frame');
	is($frame->type_string, 'SETTINGS', 'have SETTINGS as type');
	is($frame->setting('MAX_CONCURRENT_STREAMS'), 1000, 'MAX_CONCURRENT_STREAMS = 1000');
	is($frame->setting('INITIAL_WINDOW_SIZE'), 10485760, 'INITIAL_WINDOW_SIZE = 10485760');
	is("$frame", "SPDY:SETTINGS, control, INITIAL_WINDOW_SIZE=10485760,MAX_CONCURRENT_STREAMS=1000", 'stringified frame');
}
{ # Stream frame
	my $pkt = join "", map chr hex, qw(
		80 03 00 01 01 00 01 3a 00 00 00 01 00 00 00 00
		00 00 38 ea e3 c6 a7 c2 02 65 1b 50 76 b2 82 16
		08 7c a0 ac 9a 03 e2 58 59 5a 1a 59 82 92 aa 15
		22 41 bb bb 86 80 15 17 24 82 8b 2d 46 80 00 d2
		07 08 20 b0 7c 31 b0 90 cc 05 97 a4 19 25 25 05
		a0 84 ce 61 85 3d 7d 23 0a 71 7b 44 a0 61 0f 06
		b4 c0 b2 06 39 d6 52 47 4b 5f 0b cc b2 c0 5e ea
		0b 62 04 06 f6 aa 40 2a 35 4f d7 dd 09 18 04 ba
		a1 c1 10 f3 80 6c 30 c3 0c 5b b1 cf 09 10 40 b9
		89 15 ba 89 e9 a9 b6 06 00 01 04 f2 03 3c 3b 9a
		03 04 20 08 0e 8e 00 04 81 18 00 b6 24 9c 27 98
		19 8b 81 88 3f 7e 79 a6 78 77 f7 13 e7 aa 70 1d
		47 40 e6 08 c8 25 49 c8 17 3f 42 6e 8d 13 72 79
		ef 0e 39 e7 4a e8 17 40 18 05 4c 86 6f 7e 55 66
		4e 4e a2 be a9 9e 81 82 46 84 a1 a1 b5 82 4f 66
		5e 69 85 42 85 85 59 bc 99 89 26 30 f5 02 d3 7a
		78 6a 92 77 66 89 be a9 b1 b9 9e b1 99 82 86 b7
		47 88 af 8f 8e 42 4e 66 76 aa 82 7b 6a 72 76 be
		a6 82 73 06 b0 74 4f d5 37 b2 d0 33 d0 33 04 66
		20 3d 73 43 60 8a 4d 4b 2c ca 84 ea 02 00 00 00
		ff ff
	);
	ok(my $frame = Protocol::SPDY::Frame->parse(\$pkt, zlib => $zlib), 'parse SYN_STREAM frame');
	is($frame->type_string, 'SYN_STREAM', 'correct type');
	is($frame->header(':host'), 'localhost:9929', 'host header');
	is("$frame", "SPDY:SYN_STREAM, control, :host=localhost:9929,:method=GET,:path=/,:scheme=https,:version=HTTP/1.1,accept=text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8,accept-encoding=gzip,deflate,sdch,accept-language=en-GB,en-US;q=0.8,en;q=0.6,cache-control=max-age=0,cookie=m=34e2:|2a03:t|ca3:t|15cc:t|6cfc:t|77cb:t|1d98:t|5be5:t,user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36", 'stringified frame');
}
