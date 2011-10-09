package Dwimmer::Client;
use Moose;

use WWW::Mechanize;
use JSON qw(from_json);

has host => (is => 'ro', isa => 'Str', required => 1);
has mech => (is => 'rw', isa => 'WWW::Mechanize', default => sub { WWW::Mechanize->new } );


our $VERSION = '0.1101';

# get_user parameters can be    id => 1
sub get_page {
	my ($self, $filename, $revision) = @_;
	my $m = $self->mech;
	my $url = $self->host . '/_dwimmer/page.json?filename=' . $filename;
	$url .= "&revision=$revision" if defined $revision;
	$m->get($url);
	return from_json $m->content;
}

sub save_page {
	my ($self, %args) = @_;
	my $m = $self->mech;
	$args{editor_body} = delete $args{body};
	$args{editor_title} = delete $args{title};
	$m->post( $self->host . "/_dwimmer/save_page.json", \%args );
	return from_json $m->content;
}


my %GET = map { $_ => $_ } qw(
	feed_collectors
	feeds
	fetch_lists
	get_pages
	get_user
	history
	list_members
	list_users
	logout
	register_email
	session
	validate_email
);
my %POST = map { $_ => $_ } qw(
	add_feed
	add_user
	create_feed_collector
	create_list
	create_site
	login
);

AUTOLOAD {
	our $AUTOLOAD;
	(my $sub = $AUTOLOAD) =~ s/^Dwimmer::Client:://;
	my ($self, %attr) = @_;

	my $m = $self->mech;
	if ($GET{$sub}) {
		my $params = join "&", map { "$_=$attr{$_}" } keys %attr;
		my $url = $self->host . "/_dwimmer/$GET{$sub}.json?$params";
		#warn $url;
		$m->get($url);
	} elsif ($POST{$sub}) {
		my $url = $self->host . "/_dwimmer/$POST{$sub}.json";
		#warn $url;
		$m->post($url, \%attr);
	} else {
		die "Could not locate method '$sub'\n";
	}
	return from_json $m->content;
}

1;

