#!/usr/bin/env perl

# Probably this could be done more generally by rt-incident-submit.
# So this is evil cargo-culting of my own code. Whatever, I've got work to do.

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
use XML::XPath;
use Socket;

my $debug = 0;

my %config = ISSRT::ConConn::GetConfig();

sub resolve() {
	my $inip = shift;
	my $foo = inet_aton($inip);
	return gethostbyaddr($foo,AF_INET) || "Unknown Hostname";
}

my $inXML = 0;
my $xmlString = "";
while(<>){
	if(m/<\?xml.*?>/) {
		$inXML = 1;
	}
	if(m#</Infringement>#) {
		$xmlString .= $_;;
		$inXML = 0;
	}
	if($inXML) {
		$xmlString .= $_;;
	}
}

my ($ch,$ts,$cid,$ip,$dname,$title,$ft,$dv,$fn) = "";

if($xmlString) {
	$xmlString =~ s/(\s)&(\s)/$1&amp;$2/;
	if($debug > 0) { print "\n--\nxmlstring is:\n . " . Dumper($xmlString) . "\n"; }
	my $xp = XML::XPath->new(xml => $xmlString);
	if($debug > 0) { print "\n---\nxp is:\n" . Dumper($xp) . "\n"; }
	$ch = $xp->findvalue("/Infringement/Complainant/Entity") || "Unknown Entity";
	$ts = $xp->findvalue("/Infringement/Source/TimeStamp") || "Unknown Timestamp";
	$cid = $xp->findvalue("/Infringement/Case/ID") || "Unknown CaseID";
	$ip = $xp->findvalue("/Infringement/Source/IP_Address") || "Unknown IP";
	$dname = $xp->findvalue("/Infringement/Source/DNS_Name") || &resolve($ip); # this needs better error-checking
	$title = $xp->findvalue("/Infringement/Content/Item/Title") || "Unknown Title";
	$fn = $xp->findvalue("/Infringement/Content/Item/FileName") || "Unknown Filename";
	$ft = $xp->findvalue("/Infringement/Content/Item/Type") || "Unknown Type";
	$dv = $xp->findvalue("/Infringement/Source/Deja_Vu") || "DejaVu unset";
	$ts =~ s/T.*//;
} else {
	die "DERP HERP\n";
}

my $subject = "Copyright complaint $cid $ts $ip";

my $rttext = qq|
Entity $ch
Date $ts
CaseID $cid
SourceIP $ip
FQDN $dname
Title $title
Type $ft
DejaVu $dv
|;

if($debug > 0){
	print qq|
	Subject: $subject

	RT Text:
	$rttext
	|;
}

my $rt = RT::Client::REST->new(
	server => 'https://' . $config{hostname},
	timeout => 30,
);

try {
	$rt->login(username => $config{username}, password => $config{password});
} catch Exception::Class::Base with {
	die "problem logging in: ", shift->message;
};

# Create the ticket.
my $ticket = RT::Client::REST::Ticket->new(
	rt => $rt,
	queue => "Incidents",
	subject => $subject,
	cf => {
		'Risk Severity' => 2,
		'_RTIR_Classification' => "Copyright"
	},
)->store(text => $rttext);
print "New ticket's ID is ", $ticket->id, "\n";

