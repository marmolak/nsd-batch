#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::SSL;


my $nsd_control_version = 1;
my $reload_cmd = "NSDCT" . $nsd_control_version . ' reload ';
my $timeout = 20;

sub nsdc_conn {
	my $sock;
	local $SIG{ALRM} = sub { die "alarm\n" };
	eval {
		alarm ($timeout);
		$sock = IO::Socket::SSL->new (
			PeerAddr => 'localhost',
			PeerPort => '8952',
			Proto    => 'tcp',
			SSL_use_cert => 1,
			SSL_key_file => "/usr/local/etc/nsd/nsd_control.key",
			SSL_cert_file => "/usr/local/etc/nsd/nsd_control.pem"
			);
		if (!$sock) {
			die ("conn\n");
		}
		return 1;

	} or do {
		alarm (0);
		my $err = $@;
		if ($err) {
			if ($err =~ /^conn/) {
				print "connection failed!\n";
				print &IO::Socket::SSL::errstr () . "\n";
				exit (2);
			}

			if ($err =~ /^alarm/) {
				print "connection timeout!\n";
				exit (3);
			}
		}
	};

	return $sock;
}

sub send_cmd_reload {
	my ($sock, $zone) = @_;

	my $s = $reload_cmd . $zone . "\n";

	print "reloading zone: $zone - status: ";

	local $SIG{ALRM} = sub { die "alarm\n" };
	eval {
		alarm ($timeout);
		print $sock $s;
		my $status = <$sock>;
		print "$status";
		return 1;
	} or do {
		alarm (0);
		my $err = $@;
		if ($err) {
			if ($err =~ /^alarm/) {
				print "timeout!\n";
			}
		}
	}
}

sub main {
	my ($argv) = @_;

	foreach my $zone (@$argv) {
		my $sock = nsdc_conn ();
		send_cmd_reload ($sock, $zone);
		$sock->close ();
	}

	return 0;
}

if ($#ARGV < 0) {
	print " Usage: nsd-batch.pl <list of domains>";
	exit (1);
}

my $ret = main (\@ARGV);
exit ($ret);


# Autorelease socket
package AutoRel;
use strict;
use warnings;
sub new {
	my ($class, $fd) = @_;
	my $this = {
		fd => $fd
	};
	bless $this, $class;
	return $this;
}

sub DESTROY {
	my ($this) = @_;
	$this->{fd}->close () if ($this->{fd});
	print "release\n";
}
