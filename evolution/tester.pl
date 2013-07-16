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

package Client;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use IO::Async::Stream;
use curry::weak;

sub new { my $class = shift; bless { @_ }, $class }
sub loop { shift->{loop} }

sub connect {
	my $self = shift;
	my %args = @_;
	my $port = delete $args{port};
	warn "connecting to $port\n";
	$self->loop->SSL_connect(
		addr => {
			family   => "inet",
			socktype => "stream",
			port     => $port,
		},
		SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
		SSL_verify_mode => SSL_VERIFY_NONE,
		on_connected => $self->curry::weak::connection,
		on_ssl_error => sub { die "ssl error: @_"; },
		on_connect_error => sub { die "conn error: @_"; },
		on_resolve_error => sub { die "resolve error: @_"; },
	);
}

sub connection {
	my $self = shift;
	my $sock = shift;
	print "Connected to $sock using " . $sock->next_proto_negotiated . "\n";
	die "Wrong protocol" unless $sock->next_proto_negotiated eq 'spdy/3';
	my $spdy = Transport::SPDY->new;
	$spdy->transport($sock);
#	$spdy->queue_frame(
#		Protocol::SPDY::Frame::Control::SETTINGS->new(
#			flags => 0,
#			version => 3,
#		)
#	);
	$spdy->queue_frame(
		Protocol::SPDY::Frame::Control::SYN_STREAM->new(
			flags => 0,
			stream_id => $frame->stream_id,
			version => 3,
			nv => [
				':status' => '200 OK',
				':version' => 'HTTP/1.1',
				'server' => 'ProtocolSPDY/0.002',
				'content-type' => 'text/plain; charset=utf-8',
				'content-length' => length($reply),
			],
		)
	);
}

package Server;
use IO::Async::Stream;
use curry::weak;

sub new { my $class = shift; bless { @_ }, $class }
sub loop { shift->{loop} }

sub accept {
	my $self = shift;
	my $sock = shift;
	print "Client connected to $sock, we're using " . $sock->next_proto_negotiated . "\n";
	die "Wrong protocol" unless $sock->next_proto_negotiated eq 'spdy/3';
	my $stream = IO::Async::Stream->new(handle => $sock);
	my $spdy = Transport::SPDY->new;
	$spdy->transport($stream);
	$stream->configure(
		on_read => sub {
			my ( $self, $buffref, $eof ) = @_;
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
	$self->loop->add($stream);
}

sub listen {
	my $self = shift;
	my $sock = shift;
	my $port = $sock->sockport;
	print "Listening on port $port\n";
	$self->listener_ready->done($port);
}

sub listener_ready {
	my $self = shift;
	$self->{listener_ready} ||= Future->new
}

sub start {
	my $self = shift;
	my %args = @_;
	$self->loop->SSL_listen(
		addr => {
			family   => "inet",
			socktype => "stream",
			port     => 0,
		},
		SSL_npn_protocols => [ 'spdy/3', 'http1.1' ],
		SSL_cert_file => 'certs/examples.crt',
		SSL_key_file => 'certs/examples.key',
		SSL_ca_path => 'certs/ProtocolSPDYCA',
		on_accept => $self->curry::weak::accept,
		on_ssl_error => sub { die "ssl error: @_"; },
		on_connect_error => sub { die "conn error: @_"; },
		on_resolve_error => sub { die "resolve error: @_"; },
		on_listen => $self->curry::weak::listen,
	);
}

package main;
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use IO::Async::Loop;
use IO::Async::SSL;
use Future;

my $loop = IO::Async::Loop->new;
my $server = Server->new(loop => $loop);
$server->listener_ready->on_done(sub {
	my $port = shift;
	warn "Port is $port\n";
	my $client = Client->new(
		loop => $loop,
	);
	$client->connect(
		port => $port
	);
});
$server->start;
$loop->run;
