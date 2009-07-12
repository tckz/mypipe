#!/usr/bin/perl

use utf8;
use strict;
use warnings;
no warnings 'uninitialized';

use URI;
use WWW::Mechanize;
use Web::Scraper;
use DateTime;
use YAML;
use DateTime::Format::W3CDTF;


my	$uri = URI->new(q|http://rikunabi-next.yahoo.co.jp/tech/docs/ct_s01300.jsp?p=028|);
my $mech = WWW::Mechanize->new(cookie_jar => {});
if(-t STDERR)
{
	$mech->show_progress(1);
}
my $res = $mech->get($uri);
if(!$res->is_success)
{
	die $res->status_line;
}

my	$result = scraper {
	process '//title', 'title' => 'TEXT';
	process '//td[@class="j-18-120"]', 'entry[]' => scraper {
		process '//a', 'title' => 'TEXT';
		process '//a', 'link' => '@href';
		process '//span' , 'date' => sub {
			my($n) = @_;
			my	$t = $n->as_trimmed_text;
			if($t =~ /\(([0-9]+)\.([0-9]+)\.([0-9]+)\)/)
			{
				my($y, $m, $d) = ($1, $2, $3);
				$y += 2000 if $y < 100;
				my $dt = DateTime->new(
					year => $y,
					month => $m,
					day => $d,
					time_zone => 'local',
				);

				my $f = DateTime::Format::W3CDTF->new;
				return $f->format_datetime($dt);
			}
			return	undef;
		};
	};
}->scrape($res->decoded_content, $mech->uri);

$result->{link} = $uri->as_string;

binmode STDOUT, ":utf8";
local $YAML::Stringify = 1;
print YAML::Dump $result;
#use Data::Dumper;
#print Dumper($result);

0;

