#!/usr/bin/env perl
use strict;
use warnings;

# Search an RTIR *Incident* queue for a given string in a subject
# Mike Patterson <mike.patterson@uwaterloo.ca>
# in his guise as IST-ISS staff member, April 2012

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

my $rt = RT::Client::REST->new(
	server => 'https://' . $config{hostname},
	timeout => 30,
);

try {
	$rt->login(username => $config{username}, password => $config{password});
} catch Exception::Class::Base with {
	die "problem logging in: ", shift->message;
};

my $searchstr = $ARGV[0] || die "No search string given\n";

my $qstring = qq|
Queue = 'Incidents'
AND Subject LIKE '%$searchstr%'
|;
if($debug > 0){ print "Query string\n$qstring\n"; }

my @ids = $rt->search(
	type => 'ticket',
	query => $qstring
);

if($debug > 0){	print scalar @ids . " incidents\n"; }
if($debug > 1){	print Dumper(@ids); }

# Going to want: id, Subject, RTIR_IP, RTIR_State, Classification
for my $id (@ids) {
	# show() returns a hash reference
	my ($ticket) = $rt->show(type=>'ticket',id=>$id);
	if($debug > 0) {
		print Dumper($ticket);
	}
	my $class = $ticket->{'CF.{_RTIR_Classification}'};
	my $subj = $ticket->{'Subject'};
	my $state = $ticket->{'CF.{_RTIR_State}'};
	my $cdate = $ticket->{'Created'};
	my $rdate = $ticket->{'Resolved'} || 'Still open';
	my $queue = $ticket->{'Queue'};
	my $url = "https://rt.uwaterloo.ca/RTIR/Display.html?id=$id";
	print "$url\nID: $id ($state)\tQueue: $queue\nSubject: $subj\nClassification: $class\nCreated: $cdate\nResolved: $rdate\n\n";
}
