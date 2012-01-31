package Protocol::SPDY::Test;
use strict;
use warnings;
use Protocol::SPDY::Constants ':all';
use Protocol::SPDY::Frame;
use Exporter qw(import);
use Test::More;
use Try::Tiny;

our @EXPORT_OK = qw(control_frame_ok);
our %EXPORT_TAGS = (
	'all' => \@EXPORT_OK
);

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
				is($frame->$_, $spec->{$_}, $_ . ' matches') for grep exists $spec->{$_}, qw(stream_id priority associated_stream_id);
			} catch {
				fail('Had exception during subtest: ' . $_);
			};
			done_testing;
		};
	}
);

=head2 control_frame_ok

Tests whether the given frame is valid.

Takes the following parameters:

=over 4

=item * $frame - the L<Protocol::SPDY::Frame> object to test

=item * $spec - the spec to test against, default empty

=item * $msg - message to display in test notes

=back

=cut

sub control_frame_ok($$$) {
	my $frame = shift;
	my $spec = shift || {};
	my $msg = shift || '';
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

1;
