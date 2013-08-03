use strict;
use warnings;
use Protocol::SPDY::Server;

use Test::More;

{
	package SPDY::Transport;
	sub new { my $class = shift; bless { }, $class }
}

my $spdy = new_ok('Protocol::SPDY' => [
	# Server is requesting to send some data across the wire
	on_write => sub { die "should not write" },
]);

my $outgoing = '';
my $server = new_ok('Protocol::SPDY::Server' => [
	# Server is requesting to send some data across the wire
	on_write => sub { $outgoing .= shift; },
	transport => SPDY::Transport->new
]);
for(1..1) {
	ok(my $stream = $server->create_stream, 'create a new stream');
	is($stream->id % 2, 0, 'even-numbered stream ID');
	ok($stream->id, 'stream ID is nonzero');
	ok($server->has_stream($stream), 'server knows about this stream');
	ok(!$stream->seen_reply, 'new stream has no reply');
	is($outgoing, '', 'have no data yet');
	ok($stream->start, 'send SYN');
	ok(length($outgoing), 'have outgoing data');
	isa_ok(my $frame = $spdy->extract_frame(\$outgoing), 'Protocol::SPDY::Frame::Control::SYN_STREAM');
}
done_testing();

