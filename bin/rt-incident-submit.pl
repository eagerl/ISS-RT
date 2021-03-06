#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use Config::General;
use RT::Client::REST;
use RT::Client::REST::Ticket;
use Error qw|:try|;
use Date::Manip;
use ConConn;
use Scalar::Util qw(looks_like_number);

my $debug = 0;

my %config = ISSRT::ConConn::GetConfig();

my $subject = $ARGV[0] || die "Need a subject\n";
my $infilename = $ARGV[1] || die "Need a file name\n";
my $pri;
if($pri = $ARGV[2]){
	die "Priority must be a digit (1-5)\n" unless looks_like_number($pri);
} else {
	$pri = 3;
}
$/ = undef; # we're going to want to read a whole file into a string
open(FILE,"$infilename") || die "Couldn't open file $infilename $!\n";
my $rttext = <FILE>;
close(FILE);

my $rt = RT::Client::REST->new(
	server => 'https://' . $config{hostname},
	timeout => 30,
);

try {
	$rt->login(username => $config{username}, password => $config{password});
} catch Exception::Class::Base with {
	die "problem logging in: ", shift->message;
};

my $ticket = RT::Client::REST::Ticket->new(
	rt => $rt,
	queue => "Incidents",
	subject => $subject,
	cf => {
		'Risk Severity' => $pri
	},
)->store(text => $rttext);
print "New ticket's ID is ", $ticket->id, "\n";

