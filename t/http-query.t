use strict;
use warnings;

use Test::More tests => 1;

my $req = $proto->request(
	uri => URI->new('http://example.com/some/path?query=value&otherquery=othervalues'),
);

