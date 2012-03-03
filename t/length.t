use strict;
use warnings;

use Test::More tests => 3;
use Protocol::SPDY;

my $pkt = new_ok('Protocol::SPDY::Frame::Control');
{
my $flags = $pkt->control_flags;
ok($pkt->length(78), 'set length');
is($flags, $pkt->control_flags, 'flags are unchanged');
}
