use strict;
use warnings;

use Test::More tests => 8;
use Protocol::SPDY::Constants qw(:all);

# check control frame message type codes are correct
is(SYN_STREAM,  1, 'SYN_STREAM');
is(SYN_REPLY,   2, 'SYN_REPLY');
is(RST_STREAM,  3, 'RST_STREAM');
is(SETTINGS,    4, 'SETTINGS');
is(NOOP,        5, 'NOOP');
is(PING,        6, 'PING');
is(GOAWAY,      7, 'GOAWAY');
is(HEADERS,     8, 'HEADERS');
