package Protocol::SPDY::Stream;
use strict;
use warnings;
use parent qw(Mixin::Event::Dispatch);

=head1 NAME

Protocol::SPDY::Stream - single stream representation within a L<Protocol::SPDY> connection

=head1 SYNOPSIS

 # You'd likely be using a subclass or other container here instead
 my $spdy = Protocol::SPDY->new;
 # Create initial stream - this example is for an HTTP request
 my $stream = $spdy->create_frame(
   # 0 is the default, use 1 if you don't want anything back from the
   # other side, for example server push
   unidirectional => 0,
   # Set to 1 if we're not expecting to send any further frames on this stream
   # - a GET request with no additional headers for example
   fin => 0,
   # Normally headers are provided as an arrayref to preserve order,
   # but for convenience you could use a hashref instead
   headers => [
     ':method'  => 'PUT',
     ':path:'   => '/some/path?some=param',
     ':version' => 'HTTP/1.1',
     ':host'    => 'localhost:1234',
     ':scheme'  => 'https',
   ]
 );
 # Update the headers - regular HTTP allows trailing headers, with SPDY
 # you can send additional headers at any time
 $stream->headers(
   # There's more to come
   fin => 0,
   # Again, arrayref or hashref are allowed here
   headers => [
     'content-length' => 5,
   ]
 );
 # Normally scalar (byte) data here, although scalar ref (\'something')
 # and Future are also allowed
 $stream->send_data('hello');
 # as a scalar ref:
 # $stream->send_data(\(my $buffer = "some data"));
 # as a Future:
 # $stream->send_data(my $f = Future->new);
 # $f->done('the data you expected');
 # If you want to cancel the stream at any time, use ->reset
 $stream->reset('CANCEL') # or STREAM_CANCEL if you've imported the constants
 # Normally you'd indicate finished by marking a data packet as the final one:
 $stream->send_data('</html>', fin => 1);

=head1 DESCRIPTION

=head2 HTTP semantics

Each stream corresponds to a single HTTP request/response exchange. The request
is contained within the SYN_STREAM frame, with optional additional HEADERS
after the initial stream creation, and the response will be in the SYN_REPLY,
which must at least include the C<:status> and C<:version> headers (so
the SYN_REPLY must contain the C<200 OK> response, you can't send that in
a later HEADERS packet).

=head2 Window handling

Each outgoing data frame will decrement the window size; a data frame
can only be sent if the data length is less than or equal to the remaining
window size. Sending will thus be paused if the window size is insufficient;
note that it may be possible for the window size to be less than zero.

* Each frame we receive and process will trigger a window update response.
This applies to data frames only; windowing does not apply to control frames.
If we have several frames queued up for processing, we will defer the window
update until we know the total buffer space freed by processing those frames.
* Each data frame we send will cause an equivalent reduction in our window
size

* Extract all frames from buffer
* For each frame:
  * If we have a stream ID for the frame, pass it to that stream
* Stream processing for new data
  * Calculate total from all new data frames
  * Send window update if required

=cut

use Protocol::SPDY::Constants ':all';
use Scalar::Util ();

use overload
	'""' => 'to_string',
	bool => sub { 1 },
	fallback => 1;

=head2 METHODS

=cut

sub new {
	my $class = shift;
	my $self = bless {
		@_,
		from_us => 1,
	}, $class;
	Scalar::Util::weaken($self->{connection});
	$self;
}

sub new_from_syn {
	my $class = shift;
	my $frame = shift;
	my %args = @_;
	my $self = bless {
		id         => $frame->stream_id,
		connection => $args{connection},
		from_us    => 0,
	}, $class;
	Scalar::Util::weaken($self->{connection});
	$self->update_received_headers_from($frame);
	$self;
}

sub update_received_headers_from {
	my $self = shift;
	my $frame = shift;
	my $hdr = $frame->headers_as_simple_hashref;
	$self->{received_headers}{$_} = $hdr->{$_} for keys %$hdr;
	$self
}

sub from_us { shift->{from_us} ? 1 : 0 }

sub id { shift->{id} }

sub seen_reply { shift->{seen_reply} ? 1 : 0 }

sub connection { shift->{connection} }

sub priority { 1 }
sub version { 3 }

sub syn_frame {
	my $self = shift;
	Protocol::SPDY::Frame::Control::SYN_STREAM->new(
		stream_id => $self->id,
		priority  => $self->priority,
		slot      => 0,
		version   => $self->version,
		flags     => 0,
		headers   => [],
	);
}

sub sent_header { $_[0]->{sent_headers}{$_[1]} }
sub sent_headers { $_[0]->{sent_headers} }
sub received_header { $_[0]->{received_headers}{$_[1]} }
sub received_headers { $_[0]->{received_headers} }

sub handle_frame {
	my $self = shift;
	my $frame = shift;
	if($frame->is_data) {
		$self->invoke_event(data => $frame);
	} elsif($frame->type_name eq 'WINDOW_UPDATE') {
		die "we have a window update";
	} elsif($frame->type_name eq 'RST_STREAM') {
		return $self->accepted->fail($frame->status_code_as_text) if $self->from_us;
		$self->closed->fail($frame->status_code_as_text);
	} elsif($frame->type_name eq 'SYN_REPLY') {
		die "SYN_REPLY on a stream which has already been refused or replied" if $self->accepted->is_ready;
		$self->accepted->done;
		$self->replied->done;
	} elsif($frame->type_name eq 'HEADERS') {
		die "HEADERS on a stream which has not yet seen a reply" unless $self->accepted->is_ready;
		foreach my $k ($frame->header_list) {
			$self->{received_headers}->{$k} = $frame->header($k);
		}
		$self->invoke_event(headers => $frame);
	} elsif($frame->type_name eq 'SYN_STREAM') {
		die "SYN_STREAM on an existing stream";
	} else {
		die "what is $frame ?";
	}
}

sub queue_frame {
	my $self = shift;
	my $frame = shift;
	$self->connection->queue_frame($frame);
}

sub start {
	my $self = shift;
	$self->queue_frame($self->syn_frame);
	$self
}

=head2 reply

Sends a reply to the stream instantiation request.

=cut

sub reply {
	my $self = shift;
	my %args = @_;
	my $flags = 0;
	$flags |= FLAG_FIN if $args{fin};
	$self->queue_frame(
		Protocol::SPDY::Frame::Control::SYN_REPLY->new(
			stream_id => $self->id,
			version   => $self->version,
			flags     => $flags,
			headers   => $args{headers},
		)
	);
}

=head2 reset

Sends a reset request for this frame.

=cut

sub reset {
	my $self = shift;
	my $status = shift;
	$self->queue_frame(
		Protocol::SPDY::Frame::Control::RST_STREAM->new(
			stream_id => $self->id,
			status    => $status,
		)
	);
}

=head2 headers

Send out headers for this frame.

=cut

sub headers {
	my $self = shift;
}

=head2 window_update

Update information on the current window progress.

=cut

sub window_update {
	my $self = shift;
}

=head2 send_data

Sends a data packet.

=cut

sub send_data {
	my $self = shift;
	my $data = shift;
	my %args = @_;
	$self->queue_frame(
		Protocol::SPDY::Frame::Data->new(
			%args,
			stream_id => $self->id,
			payload   => $data,
		)
	);
	$self
}

=head2 METHODS - Accessors

These provide read-only access to various pieces of state information.

=head2 remote_fin

Returns true if the remote has sent us a FIN (half-closed state).

=cut

sub remote_fin { shift->{remote_fin} ? 1 : 0 }

=head2 local_fin

Returns true if we have sent FIN to the remote (half-closed state).

=cut

sub local_fin { shift->{local_fin} ? 1 : 0 }

=head2 initial_window_size

Initial window size. Default is 64KB for a new stream.

=cut

sub initial_window_size { shift->{initial_window_size} }

=head2 transfer_window

Remaining bytes in the current transfer window.

=cut

sub transfer_window { shift->{transfer_window} }

=head2 METHODS - Futures

The following L<Future>-returning methods are available. Attach events using
C<on_done>, C<on_fail> or C<on_cancel> or helpers such as C<then> as usual:

 $stream->replied->then(sub {
   # This also returns a Future, allowing chaining
   $stream->send_data('...')
 })->on_fail(sub {
   die 'here';
 });

or from the server side:

 $stream->closed->then(sub {
   # cleanup here after the stream goes away
 })->on_fail(sub {
   die "Our stream was reset from the other side: " . shift;
 });

=cut

=head2 replied

We have received a SYN_REPLY from the other side. If the stream is reset before
that happens, this will be cancelled with the reason as the first parameter.

=cut

sub replied {
	my $self = shift;
	$self->{future_replied} ||= Future->new->on_done(sub {
		$self->{seen_reply} = 1
	})
}

=head2 finished

This frame has finished sending everything, i.e. we've set the FIN flag on a packet.
The difference between this and L</closed> is that the other side may have more to
say. Will be cancelled with the reason on reset.

=cut

sub finished {
	my $self = shift;
	$self->{future_finished} ||= Future->new
}

=head2 closed

The stream has been closed on both sides - either through reset or "natural causes".
Might still be cancelled if the parent object disappears.

=cut

sub closed {
	my $self = shift;
	$self->{future_closed} ||= Future->new
}

=head2 accepted

The remote accepted this stream immediately after our initial SYN_STREAM. If you
want notification on rejection, use an ->on_fail handler on this method.

=cut

sub accepted {
	my $self = shift;
	$self->{future_accepted} ||= Future->new
}


sub to_string {
	my $self = shift;
	'SPDY:Stream ID ' . $self->id
}

1;

__END__

=head1 COMPONENTS

Further documentation can be found in the following modules:

=over 4

=item * L<Protocol::SPDY> - top-level protocol object

=item * L<Protocol::SPDY::Frame> - generic frame class

=item * L<Protocol::SPDY::Frame::Control> - specific subclass for control frames

=item * L<Protocol::SPDY::Frame::Data> - specific subclass for data frames

=back

=head1 AUTHOR

Tom Molesworth <cpan@entitymodel.com>

=head1 LICENSE

Copyright Tom Molesworth 2011-2013. Licensed under the same terms as Perl itself.

