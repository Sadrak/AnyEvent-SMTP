#!/usr/bin/env perl


use strict;
use warnings;
use AnyEvent;
use AnyEvent::Socket;

use lib::abs '../lib';

use Test::More;
BEGIN {
	eval { require Test::SMTP;1 } or plan skip_all => 'Test::SMTP required';
}
use AnyEvent::SMTP::Server 'smtp_server';

our $port = 1024 + $$ % (65535-1024) ;
our $ready = 0;
$SIG{INT} = $SIG{TERM} = sub { exit 0 };

our $child;
unless($child = fork) {
	# Start server and wait for connections
	my $cv = AnyEvent->condvar;
	my $req = 2;
	smtp_server undef, $port, sub {};
	$cv->recv;
} else {
	# Wait for server to start
	my $cv = AnyEvent->condvar;
	my ($conn,$cg);
	$cv->begin(sub {
		undef $conn;
		undef $cg;
		$cv->send;
	});
	$conn = sub {
		$cg = tcp_connect '127.0.0.1',$port, sub {
			#warn "Conn @_";
			return $cv->end if @_;
			$conn->();
		};
	};
	$conn->();
	$cv->recv;
}

plan tests => 13;

SKIP:
for (['S1', Host => 'localhost:'.$port, AutoHello => 1]) {
	my $n = $_->[0];
	my $client = Test::SMTP->connect_ok(@$_) or skip 'Not connected',12;
	#$client->auth_ko(1,2,3,'auth');
	$client->mail_from_ok('mons@rambler-co.ru', 'Mail from');
	$client->rcpt_to_ok('mons@rambler-co.ru', 'Rcpt to');
	$client->rset_ok('Rset');

	$client->mail_from_ok('mons@rambler-co.ru', 'Mail from');
	$client->rcpt_to_ok('mons@rambler-co.ru', 'Rcpt to');
	$client->rcpt_to_ok('makc@rambler-co.ru', 'Rcpt to');
	$client->data_ok('Data');

	$client->mail_from_ok('mons@rambler-co.ru', 'Mail from');
	$client->rcpt_to_ok('mons@rambler-co.ru', 'Rcpt to');
	$client->rcpt_to_ok('makc@rambler-co.ru', 'Rcpt to');
	$client->data_ok('Data');

	$client->quit_ok('Quit OK');
}

END {
	if ($child) {
		#warn "Killing child $child";
		$child and kill TERM => $child or warn "$!";
		waitpid($child,0);
		exit 0;
	}
}
