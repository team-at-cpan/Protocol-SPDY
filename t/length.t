use strict;
use warnings;

use Test::More tests => 3;
use Protocol::SPDY;

my $pkt = new_ok('Protocol::SPDY::Frame');
{
my $flags = $pkt->flags;
ok($pkt->length(78), 'set length');
is($flags, $pkt->flags, 'flags are unchanged');
}
