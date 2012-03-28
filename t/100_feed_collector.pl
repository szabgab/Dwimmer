use strict;
use warnings;

use Test::More;

use Capture::Tiny qw(capture);
use File::Temp    qw(tempdir);

my $tempdir = tempdir( CLEANUP => 1);

plan tests => 10;

my $store = "$tempdir/data.db";
system "$^X script/dwimmer_feed_setup.pl $store";


{
	my ($out, $err) = capture { system "$^X script/dwimmer_feed_admin.pl" };
	like $err, qr{--store storage.db}, 'needs --storage';
}

my $first = {
           'comment' => 'some comment',
           'feed' => 'http://dwimmer.com/atom.xml',
           'id' => 1,
           'status' => 'enabled',
           'title' => 'This is a title',
           'twitter' => 'chirip',
           'url' => 'http://dwimmer.com/'
         };

my $second = {
           'comment' => '',
           'feed' => 'http://szabgab.com/rss.xml',
           'id' => 2,
           'status' => 'enabled',
           'title' => 'My web site',
           'twitter' => 'micro blog',
           'url' => 'http://szabgab.com/'
         };


{
	my $infile = save_infile('http://dwimmer.com/', 'http://dwimmer.com/atom.xml', 'This is a title', 'chirip', 'some comment');
	my ($out, $err) = capture { system "$^X script/dwimmer_feed_admin.pl --store $store --add < $infile" };

	like $out, qr{URL.*Feed.*Title.*Twitter.*Comment}s, 'prompts';
	my $data = check_dump($out);

	is_deeply $data, $first, 'dumped correctly';
	is $err, '', 'no STDERR';
}
{
	my $infile = save_infile('http://szabgab.com/', 'http://szabgab.com/rss.xml', 'My web site', 'micro blog', '');
	my ($out, $err) = capture { system "$^X script/dwimmer_feed_admin.pl --store $store --add < $infile" };
	my $data = check_dump($out);
	is_deeply $data, $second, 'dumped correctly';
	is $err, '', 'no STDERR';
}

{
	my ($out, $err) = capture { system "$^X script/dwimmer_feed_admin.pl --store $store --list dwim" };
	my $data = check_dump($out);
	is_deeply $data, $first, 'listed correctly';
	is $err, '', 'no STDERR';
}
{
	my ($out, $err) = capture { system "$^X script/dwimmer_feed_admin.pl --store $store --list" };
	my $data = check_dump($out);
	is_deeply $data, $second, 'listed correctly';
	is $err, '', 'no STDERR';
}


sub check_dump {
	my ($out) = @_;

	our $VAR1 = undef;

	my ($dump) = $out =~ /(\$VAR1.*)/s;
	#diag $out;
	#diag $dump;
	eval $dump;
	die $@ if $@;
	return $VAR1;
}

sub save_infile {
	my @in = @_;

	my $infile = "$tempdir/in";
	open my $tmp, '>', $infile or die;
	print $tmp join '', map {"$_\n"} @in;
	close $tmp;
	return $infile;
}


