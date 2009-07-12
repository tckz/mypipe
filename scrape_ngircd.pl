#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings 'uninitialized';

use URI;
use WWW::Mechanize;
use Web::Scraper;
use DateTime;
use YAML::Syck;
use DateTime::Format::W3CDTF;
use Data::Dumper;
use URI::Escape;
use Getopt::Long;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my	$options = {
	save_response => undef,
	last_modified => undef,
};

if(!GetOptions(
	'save-response=s' => \$options->{save_response},
	'last-modified=s' => \$options->{last_modified},
))
{
	print STDERR "*** bad option\n";
	exit 1;
}


my  $uri = URI->new(q|http://ngircd.barton.de/doc/ChangeLog|);
my	$fn_res = $options->{save_response};
my	$res;
if($fn_res ne "" && -f $fn_res)
{
	my	$fh;
	open($fh, "<:raw", $fn_res) or die $!;
	my	$t = "";
	while(<$fh>)
	{
		$t .= $_;
	}
	close $fh;
	$res = HTTP::Response->parse($t);
}
else
{
	my $mech = WWW::Mechanize->new(cookie_jar => {});
	if(-t STDERR)
	{
		$mech->show_progress(1);
	}

	my	%add_header;
	if($options->{last_modified} ne "" && -f $options->{last_modified})
	{
		my	$mtime = (stat($options->{last_modified}))[9];
		use HTTP::Date qw(time2str);
		my	$last_modified = time2str($mtime);
		$add_header{'If-Modified-Since'} = $last_modified;
	}
	$res = $mech->get($uri, %add_header);
	if(!$res->is_success)
	{
    	die $res->status_line;
	}

	if($fn_res ne "")
	{
		my	$fh;
		open($fh, ">:raw", $fn_res) or die $!;
		print $fh $res->as_string;
		close $fh;
	}
}

my $t = $res->decoded_content;
my	$result = {
	link => $uri->as_string,
	title => q|ngIRCd - Changelog|,
	entry => [],
};
my	$rec = {};
my	$flush_entry = sub {
	my	$link = $uri->clone;
	if($rec->{time} ne "")
	{
		my	$dt = DateTime->from_epoch(epoch => $rec->{time});
		my $f = DateTime::Format::W3CDTF->new;
		$rec->{date} = $f->format_datetime($dt);

		$link->fragment($rec->{time});

		delete $rec->{time};
	}
	$rec->{link} = $link->as_string;


	push(@{$result->{entry}}, $rec);

	$rec = {};
};
foreach my $line(split(/\n/, $t))
{
	use Date::Parse qw(str2time);
	if($line =~ /^(ngIRCd.*)\s*\(([0-9:\.-]+)\)/o)
	{
		if($rec->{title} ne "")
		{
			$flush_entry->();
		}
		$rec->{title} = $1;
		$rec->{time} = str2time($2);
	}
	elsif($rec->{title} ne "")
	{
		$rec->{body} .= $line ."\n";
	}
}
if($rec->{title} ne "")
{
	$flush_entry->();
}

local $YAML::Syck::ImplicitUnicode = 1;
print YAML::Syck::Dump $result;

exit 0

