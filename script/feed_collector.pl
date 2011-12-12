#!/usr/bin/perl
use strict;
use warnings;
use v5.8;

use Dwimmer::Feed::DB;
use Dwimmer::Feed::Collector;
use Dwimmer::Feed::Sendmail;

use Getopt::Long qw(GetOptions);

my %opt;
GetOptions(\%opt,
	'store=s',

	'collect',
	'sendmail',
	'html=s',
) or usage();
usage() if not $opt{store};

my $t0 = time;

my $collector = Dwimmer::Feed::Collector->new(%opt);

if ($opt{collect}) {
	$collector->collect();
}

if ($opt{html}) {
	$collector->generate_html( $opt{html} );
}

if ($opt{sendmail}) {
	my $mail = Dwimmer::Feed::Sendmail->new(%opt);
	$mail->send;
}

if ($opt{tweet}) {
	# TODO: tweet
}

my $t1 = time;
LOG("Elapsed time: " . ($t1-$t0));
exit;


sub LOG {
	print "@_\n";
}

sub usage {
	die "Usage: $0 --store storage.db  [--collect --sendmail --html DIR]\n";
}

# TODO: display when were feeds last colleted
# TODO: comprehensive link collection (sources: feeds, aggregators, twitter, reddit), delicious
# TODO: languages
# TODO: display summary of all, allow for javascript setting which language(s) to show
# TODO: display social icons with counters (Twitter, Reddit, Google+, FaceBook, HackerNews)


