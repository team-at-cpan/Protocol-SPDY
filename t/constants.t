use strict;
use warnings;

use Test::More tests => 5;
use Digest::MD5 qw(md5_hex);
use Protocol::SPDY::Constants ':all';

ok(FLAG_FIN, 'have FIN flag');
ok(FLAG_COMPRESS, 'have COMPRESS flag');
ok(HEADER_LENGTH > 0, 'have nonzero header length');
ok(length ZLIB_DICTIONARY, 'have entries in dictionary');
is(lc md5_hex(ZLIB_DICTIONARY), '74e756a0ae9fbe28abed52f800fddf41', 'dictionary md5sum is correct');

