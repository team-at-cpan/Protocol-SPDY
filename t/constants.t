use strict;
use warnings;

use Test::More tests => 4;
use Protocol::SPDY::Constants ':all';

ok(FLAG_FIN, 'have FIN flag');
ok(FLAG_COMPRESS, 'have COMPRESS flag');
ok(HEADER_LENGTH > 0, 'have nonzero header length');
ok(length ZLIB_DICTIONARY, 'have entries in dictionary');

