use strict;
use warnings;

use Test::More tests => 3;
use Test::Fatal;
use Try::Tiny;

use Protocol::SPDY::Frame::Control::SynStream;
use Protocol::SPDY::Constants ':all';

=head2 control_frame_ok

Tests whether the given frame is valid.

=cut

my %frame_test = (
	SYN_STREAM() => sub {
		my $frame = shift;
		my $spec = shift || {};
		subtest "SYN_STREAM" => sub {
			plan tests => 5 + keys %$spec;
			try {
				cmp_ok($frame->length, '>=', 12, 'length must be >= 12');
				ok($frame->stream_id, 'have a stream identifier');
				is($frame->stream_id, 0+$frame->stream_id, 'identifier is numeric');
				cmp_ok($frame->priority, '>=', 0, 'priority >= 0');
				cmp_ok($frame->priority, '<=', 3, 'priority <= 3');
			} catch {
				fail('Had exception during subtest: ' . $_);
			};
			done_testing;
		};
	}
);
sub control_frame_ok($$$) {
	my $frame = shift;
	my $spec = shift;
	my $msg = shift;
	subtest "Frame validation - " . $msg => sub {
		plan tests => 8;
		try {
			isa_ok($frame, 'Protocol::SPDY::Frame::Control');
			can_ok($frame, qw(is_control is_data packet length type));
			ok($frame->is_control, 'is_control returns true');
			ok(!$frame->is_data, 'is_data returns false');
			is(join(' ', map sprintf('%02x', ord), split //, $frame->packet), join(' ', map sprintf('%02x', ord), split //, $frame->as_packet), 'cached packet matches generated');
			cmp_ok($frame->length, '>', 0, 'length is nonzero');
			ok(my $type = $frame->type, 'have a frame type');
			note 'type is ' . $type;
			try {
				$frame_test{$type}->($frame, $spec)
			} catch {
				fail('Had exception during subtest: ' . $_);
			} if exists $frame_test{$type};
		} catch {
			fail('Had exception during subtest: ' . $_);
		};
		done_testing;
	};
}

ok(exception { Protocol::SPDY::Frame::Control::SynStream->new }, 'dies without stream_id');

note Protocol::SPDY::Frame::Control::SynStream;
is(
	join(
		' ',
		map sprintf('%02x', ord), split //, Protocol::SPDY::Frame::Control::SynStream->pairs_to_nv_header(
			x => 123,
			y => 'z'
		)
	),
	"00 02 00 01 78 00 03 31 32 33 00 01 79 00 01 7a",
	'nv header encoding'
);
control_frame_ok my $frame = new_ok('Protocol::SPDY::Frame::Control::SynStream' => [
	stream_id => 1,
]), { }, 'basic';
done_testing;

