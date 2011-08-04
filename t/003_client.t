use strict;
use warnings;

use t::lib::Dwimmer::Test qw(start $admin_mail @users);

use Cwd qw(abs_path);
use Data::Dumper qw(Dumper);

my $password = 'dwimmer';

start($password);


eval "use Test::More";
require Test::WWW::Mechanize;

my $url = "http://localhost:$ENV{DWIMMER_PORT}";

plan(tests => 19);

use Dwimmer::Client;
my $admin = Dwimmer::Client->new( host => $url );
is_deeply($admin->login( 'admin', 'xyz' ), { error => 'invalid_password' }, 'invalid_password');
is_deeply($admin->login( 'admin', $password ), { success => 1 }, 'login success');
is_deeply($admin->list_users, { users => [
		{ id => 1, name => 'admin', }
	] }, 'list_users');
is_deeply($admin->get_user(id => 1), {
	id => 1,
	name => 'admin',
	email => $admin_mail,
	}, 'show user details');

is_deeply($admin->add_user( %{ $users[0] } ), { error => 'invalid_verify' }, 'no verify field provided');
$users[0]{verify} = 'abc';
is_deeply($admin->add_user( %{ $users[0] } ), { error => 'invalid_verify' }, 'really invalid verify field provided');

$users[0]{verify} = 'verified';
is_deeply($admin->add_user( %{ $users[0] } ), { error => 'email_used' }, 'try to add user with same mail');

$users[0]{email} = 'test2@dwimmer.org';
$users[0]{pw1} = $users[0]{pw2} = $users[0]{password};
is_deeply($admin->add_user( %{ $users[0] } ), { success => 1 }, 'add user with same mail');

is_deeply($admin->list_users, { users => [
		{ id => 1, name => 'admin', },
		{ id => 2, name => $users[0]{uname} },
	] }, 'list_users');

is_deeply($admin->get_user(id => 1), {
	id => 1,
	name => 'admin',
	email => $admin_mail,
	}, 'show user details');
is_deeply($admin->get_user(id => 2), {
	id => 2,
	name => $users[0]{uname},
	email => $users[0]{email},
	}, 'show user details');

my $user = Dwimmer::Client->new( host => $url );
is_deeply($user->list_users, { 
	dwimmer_version => $Dwimmer::Client::VERSION, 
	error => 'not_logged_in',
	}, 'to list_users page');
is_deeply($user->login($users[0]{uname}, $users[0]{password}), { success => 1}, 'user logged in');
is_deeply($user->get_session, { logged_in => 1, username => $users[0]{uname}, userid => 2 }, 'not logged in');
is_deeply($user->get_user(id => 2), {
	id => 2,
	name => $users[0]{uname},
	email => $users[0]{email},
	}, 'show user own details');
# TODO should this user be able to see the list of user?
# TODO this user should NOT be able to add new users

is_deeply($user->logout, { success => 1 }, 'logout');
is_deeply($user->get_session, {
	logged_in => 0, 
#	dwimmer_version => $Dwimmer::Client::VERSION,
	}, 'get_session');
#diag(explain($user->get_user(id => 2)));
is_deeply($user->get_user(id => 2), {
	dwimmer_version => $Dwimmer::Client::VERSION, 
	error => 'not_logged_in',
}, 'cannot get user data afer logout');

my $guest = Dwimmer::Client->new( host => $url );
is_deeply($guest->list_users, { 
	dwimmer_version => $Dwimmer::Client::VERSION, 
	error => 'not_logged_in',
	}, 'to list_users page');

