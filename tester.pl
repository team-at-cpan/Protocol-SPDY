#!/usr/bin/env perl 
use strict;
use warnings;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use IO::Async::Loop;
use IO::Async::SSL;

my $loop = IO::Async::Loop->new;
$loop->SSL_listen(
	addr => {
		family   => "inet",
		socktype => "stream",
		port     => 0,
	},
	SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
	SSL_cert_file => 'cert.pem',
	SSL_key_file => 'key.pem',
	on_stream => sub {
		my $sock = shift;
		print "Client connected to $sock, we're using " . $sock->next_proto_negotiated . "\n";
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
			},
			on_ssl_error => sub { die "ssl error: @_"; },
			on_connect_error => sub { die "conn error: @_"; },
			on_resolve_error => sub { die "conn error: @_"; },
		);

	},
);
$loop->run;

