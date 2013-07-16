#!/usr/bin/env perl 
use strict;
use warnings;
package Transport::SPDY;
use parent qw(Protocol::SPDY);
sub transport {
	my $self = shift;
	$self->{transport} = shift if @_;
	return $self->{transport}
}
sub write { shift->transport->write(@_) }

package main;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use IO::Async::Loop;
use IO::Async::SSL;
use IO::Async::Stream;
use Future;

sub hexdump {
	my $idx = 0;
	my @bytes = split //, join '', @_;
	print "== had " . @bytes . " bytes\n";
	while(@bytes) {
		my @chunk = splice @bytes, 0, 16;
		printf "%04x ", $idx;
		printf "%02x ", ord $_ for @chunk;
		(my $txt = join '', @chunk) =~ s/[^[:print:]]/./g;
		print "   " x (16 - @chunk);
		print for split //, $txt;
		print "\n";
		$idx += @bytes;
	}
}

my $loop = IO::Async::Loop->new;
my $server = Future->new;
my $client = Future->new;
$loop->SSL_listen(
	addr => {
		family   => "inet",
		socktype => "stream",
		# port     => 0,
		port     => 9929,
	},
	SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
	SSL_cert_file => 'certs/examples.crt',
	SSL_key_file => 'certs/examples.key',
	SSL_ca_path => 'certs/ProtocolSPDYCA',
	on_accept => sub {
		my $sock = shift;
		print "Client connected to $sock, we're using " . $sock->next_proto_negotiated . "\n";
		die "Wrong protocol" unless $sock->next_proto_negotiated eq 'spdy/3';
		my $stream = IO::Async::Stream->new(handle => $sock);
		my $spdy = Transport::SPDY->new;
		$spdy->transport($stream);
		$stream->configure(
			on_read => sub {
				my ( $self, $buffref, $eof ) = @_;
				hexdump($$buffref);
				while(my $frame = $spdy->extract_frame($buffref)) {
					print "Frame: $frame\n";
					$spdy->handle_frame($frame);
				}

				if( $eof ) {
					print "EOF\n";
				}

				return 0;
			}
		);
		$loop->add($stream);
		# $spdy->write($spdy->packet_ping);
		# $server->done;
	},
	on_ssl_error => sub { die "ssl error: @_"; },
	on_connect_error => sub { die "conn error: @_"; },
	on_resolve_error => sub { die "resolve error: @_"; },
	on_listen => sub {
		my $sock = shift;
		my $port = $sock->sockport;
		print "Listening on port $port\n";
	},
);
$loop->run for Future->needs_all($server, $client)->on_done(sub { $loop->stop });

