#!/usr/bin/env perl 
use strict;
use warnings;
use IO::Socket::SSL;
use IO::Async::Loop;
use IO::Async::SSL;

=pod

Initiate a connection using NPN to select SPDY/3 in preference to HTTP/1.1.

=cut

my $loop = IO::Async::Loop->new;
$loop->SSL_connect(
	host => 'www.google.com',
	service => 'https',
	SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
	on_connected => sub {
		my $sock = shift;
		print "Connected to $sock using " . $sock->next_proto_negotiated . "\n";
		$loop->stop;
	},
	on_ssl_error => sub { die "ssl error: @_"; },
	on_connect_error => sub { die "conn error: @_"; },
	on_resolve_error => sub { die "conn error: @_"; },
);
$loop->run;

