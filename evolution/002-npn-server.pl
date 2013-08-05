#!/usr/bin/env perl
use strict;
use warnings;

=pod

Local server+client pair, use spdy/3 NPN to establish connection.

=cut

use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use IO::Async::Loop;
use IO::Async::SSL;
use Future;

my $loop = IO::Async::Loop->new;
my $server = Future->new;
my $client = Future->new;
$loop->SSL_listen(
	addr => {
		family   => "inet",
		socktype => "stream",
		port     => 0,
	},
	SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
	SSL_cert_file => 'certs/examples.crt',
	SSL_key_file => 'certs/examples.key',
	SSL_ca_path => 'certs/ProtocolSPDYCA',
	on_accept => sub {
		my $sock = shift;
		print "Client connected to $sock, we're using " . $sock->next_proto_negotiated . "\n";
		$server->done;
	},
	on_ssl_error => sub { die "ssl error: @_"; },
	on_connect_error => sub { die "conn error: @_"; },
	on_resolve_error => sub { die "conn error: @_"; },
	on_listen => sub {
		my $sock = shift;
		my $port = $sock->sockport;
		print "Listening on port $port\n";
		$loop->SSL_connect(
			addr => {
				family   => "inet",
				socktype => "stream",
				port     => $port,
			},
			SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
			SSL_verify_mode => SSL_VERIFY_NONE,
			on_connected => sub {
				my $sock = shift;
				print "Connected to $sock using " . $sock->next_proto_negotiated . "\n";
				$client->done;
			},
			on_ssl_error => sub { die "ssl error: @_"; },
			on_connect_error => sub { die "conn error: @_"; },
			on_resolve_error => sub { die "conn error: @_"; },
		);

	},
);
$loop->run for Future->needs_all($server, $client)->on_done(sub { $loop->stop });

