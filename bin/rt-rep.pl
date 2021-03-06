#!/usr/bin/env perl

# Report on Incidents for a given time frame.
# Ignores Question Only incidents and any incident
#  with an abandoned state or resolution (wtf RT?)
# Mike Patterson <mike.patterson@uwaterloo.ca>
# in his guise as IST-ISS staff member, Feb, Jul 2012

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use Config::General;
use RT::Client::REST;
use Error qw|:try|;
use Date::Manip;
use ConConn;

my $debug = 0;

my ($ticket,$checkmonth);
my (%classifications,%constituencies);

my %config = ISSRT::ConConn::GetConfig();

# default to the previous month's issues. Sort of.
my $lm = $ARGV[0] || UnixDate("-1m -1d","%Y-%m-%d");
my $nm = $ARGV[1] || UnixDate("today","%Y-%m-01");

my $rt = RT::Client::REST->new(
	server => 'https://' . $config{hostname},
	timeout => 30,
);

try {
	$rt->login(username => $config{username}, password => $config{password});
} catch Exception::Class::Base with {
	die "problem logging in: ", shift->message;
};

my $qstring = qq|
Queue = 'Incidents'
AND Created > '$lm'
AND Created < '$nm'
AND CF.{_RTIR_Classification} != 'Question Only'
AND CF.{_RTIR_Resolution} != 'abandoned'
AND CF.{_RTIR_Status} != 'rejected'
|;
# AND CF.{_RTIR_Classification} != 'LE request'

if($debug > 0){ print "Query string\n$qstring\n"; }

my @ids = $rt->search(
	type => 'ticket',
	query => $qstring
);

if($debug > 0){	print scalar @ids . " incidents\n"; }
if($debug > 1){	print Dumper(@ids); }

for my $id (@ids) {
	# show() returns a hash reference
	my ($ticket) = $rt->show(type=>'ticket',id=>$id);
	next if($ticket->{'CF.{_RTIR_State}'} eq 'abandoned'); # RT is stupid and SQL statement can't exclude state?
	my $classkey = $ticket->{'CF.{_RTIR_Classification}'};
	my $conskey = $ticket->{'CF.{_RTIR_Constituency}'};
	$classifications{$classkey} ||= 0;
	$classifications{$classkey} += 1; # hurray for mr cout
	$constituencies{$conskey} ||= 0;
	$constituencies{$conskey} += 1;
	if($debug > 1){
		print "$id\t$conskey\t$ticket->{'Subject'}\n";
	}
	if($debug > 2){
		print Dumper($ticket);
	}
}

print "RT Incident report for $lm to $nm\nClassifications\n";

print "$classifications{$_}\t$_\n" for sort 
 { $classifications{$b} <=> $classifications{$a} } keys %classifications;

print "\nConstituencies\n";

print "$constituencies{$_}\t$_\n" for sort 
 { $constituencies{$b} <=> $constituencies{$a} } keys %constituencies;
