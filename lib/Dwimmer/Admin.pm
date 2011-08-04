package Dwimmer::Admin;
use Dancer ':syntax';

use 5.008005;

our $VERSION = '0.01';

use Data::Dumper    qw(Dumper);
use Email::Valid    ();
use MIME::Lite      ();
use String::Random  ();
use Template        ();

use Dwimmer::DB;
use Dwimmer::Tools qw(sha1_base64 _get_db _get_site);

###### routes

sub render_response {
    my ($template, $data) = @_;

    $data ||= {};
    foreach my $field (qw(logged_in username userid)) {
        $data->{$field} = session->{$field};
    };
    
    debug('render_response  ' . request->content_type );
    $data->{dwimmer_version} = $VERSION;
    my $content_type = request->content_type || params->{content_type} || '';
    if ($content_type =~ /json/ or request->{path} =~ /\.json/) {
       content_type 'text/plain';
       debug('json', $data);
       return to_json $data, { utf8 => 0, convert_blessed => 1, allow_blessed => 1 };
    } else {
       return template $template, $data;
    }
}

post '/save' => sub {
    my ($site_name, $site) = _get_site();

    return '{ "error" : "no_site" }' if not $site;
    my $file = params->{filename};
    return '{ "error" : "no_file_supplied" }' if not $file;

    # TODO check if the user has the right to save this page!
    debug( params->{text} );
    debug( params->{formtitle} );
    my $db = _get_db();
    my $page = $db->resultset('Page')->find( {siteid => $site->id, filename => $file});
    $page->body( params->{text} );
    $page->title( params->{formtitle} );
    # TODO save to history
    # TODO update author
    # TODO update timestamp
    $page->update;

    return '{ "success" : "1" }';
};

sub _authenticate {
    my $username = params->{username};
    my $password = params->{password};
    
    return render_response 'error', {missing_username => 1} if not $username;
    return render_response 'error', {missing_password => 1} if not $password;

    my $db = _get_db();
    my $user = $db->resultset('User')->find( {name => $username});
    return render_response 'error', {no_such_user => 1} if not $user;

    my $sha1 = sha1_base64($password);
    return render_response 'error', {invalid_password => 1} if $sha1 ne $user->sha1;
  
    return render_response 'error', {not_verified => 1} if not $user->verified;

    session username => $username;
    session userid   => $user->id;
    session logged_in => 1;

    return;
}

post '/login.json' => sub {
    my $username = params->{username};
    my $password = params->{password};
    
    return to_json { error => 'missing_username' } if not $username;
    return to_json { error => 'missing_password' } if not $password;

    my $db = _get_db();
    my $user = $db->resultset('User')->find( {name => $username});
    return to_json { error => 'no_such_user' } if not $user;

    my $sha1 = sha1_base64($password);
    return to_json { error => 'invalid_password' } if $sha1 ne $user->sha1;
  
    return { error => 'not_verified' } if not $user->verified;

    session username => $username;
    session userid   => $user->id;
    session logged_in => 1;

    return to_json { success => 1 };
};

post '/login' => sub {
    my $username = params->{username};
    my $password = params->{password};
    
    return render_response 'error', {missing_username => 1} if not $username;
    return render_response 'error', {missing_password => 1} if not $password;

    my $db = _get_db();
    my $user = $db->resultset('User')->find( {name => $username});
    return render_response 'error', {no_such_user => 1} if not $user;

    my $sha1 = sha1_base64($password);
    return render_response 'error', {invalid_password => 1} if $sha1 ne $user->sha1;
  
    return render_response 'error', {not_verified => 1} if not $user->verified;

    session username => $username;
    session userid   => $user->id;
    session logged_in => 1;

    # redirect to the referer except if that was 
    # the logout page or one of the error pages.
    my $referer = request->referer || '';
    my $host    = request->host;

    my $ref_path = '';
    if ($referer =~ m{^https?://$host(.*)}) {
        $ref_path = $1;
    } else {
        return redirect '/';    
    }

    my $noland_pages = join '|', ('logout');
    if ($ref_path =~ m{^/($noland_pages)}) {
        return redirect '/';
    }

    redirect $referer;
};

get '/logout' => sub {
     session->destroy;
     render_response 'goodbye';
};

get '/page' => sub {
    render_response 'page';
};

# post '/page' =>  sub {
    # my $now   = time;
    # $data->{$now} = {
        # title => params->{title},
        # text  => params->{text},
    # };
# 
    # redirect '/';
# };

get '/list_users' => sub {
    my $db = _get_db();
    my @users = $db->resultset('User')->all(); #{ select => [ qw/id uname/ ] });
    #my $html = $users[0]->uname;
    #return $html;
    render_response 'list_users', {users => \@users};
};

# static pages , 
foreach my $page ('add_user', 'needs_login') {
    get "/$page" => sub {
        render_response $page;
    };
}

get '/show_user' => sub {
    my $id = params->{id};
    return render_response 'error', { no_id => 1} if not defined $id;
    my $db = _get_db();
    my $user = $db->resultset('User')->find( $id );
    return render_response 'error', { no_such_user => 1} if not defined $id;
    return render_response  'show_user', {user => $user};
};

post '/add_user' => sub {
    my %args;
    foreach my $field ( qw(uname fname lname email pw1 pw2 verify) ) {
        $args{$field} = params->{$field} || '';
        trim($args{$field});
    }
    #return $args{verify};

    if ($args{pw1} eq '' and $args{pw2} eq '') {
        $args{pw1} = $args{pw2} = String::Random->new->randregex('[a-zA-Z0-9]{10}');
    }
    $args{tos} = 'on'; # TODO not really the right thing, mark in the database that the user was added by the admin

    return render_response 'error', { invalid_verify => 1} if $args{verify} !~ /^(send_email|verified)$/;

    my $ret = register_user(%args);
    return render_response 'error', {$ret => 1} if $ret;

    render_response '/user_added';
};

get '/register' => sub {
    render_response 'register';
};

post '/register' => sub {
    my %args;
    foreach my $field ( qw(uname fname lname email pw1 pw2 verify tos) ) {
        $args{$field} = params->{$field} || '';
        trim($args{$field});
    }
    $args{verify} = 'send_email';

    my $ret = register_user(%args);
    return render_response 'error', {$ret => 1} if $ret;

    redirect '/register_done';
};



sub register_user {
    my %args = @_;
    # validate
    $args{email} = lc $args{email};

    my $db = _get_db();
    if (length $args{uname} < 2 or $args{uname} =~ /[^\w.-]/) {
        return 'invalid_username';
    }
    my $user = $db->resultset('User')->find( { name => $args{uname} });
    if ($user) {
        return 'username_taken';
    }
    $user = $db->resultset('User')->find( {email => $args{email}});
    if ($user) {
        return 'email_used';
    }
    if (length $args{pw1} < 5) {
        return 'short_password';
    }
    if ($args{pw1} ne $args{pw2}) {
        return 'passwords_dont_match';
    }
    if ($args{tos} ne 'on') {
        return 'no_tos';
    };

    # insert new user
    my $time = time;
    my $validation_key = String::Random->new->randregex('[a-zA-Z0-9]{10}') . $time . String::Random->new->randregex('[a-zA-Z0-9]{10}');
    $user = $db->resultset('User')->create({
        name  => $args{uname},
        email => $args{email},
        sha1  => sha1_base64($args{pw1}),
        validation_key => $validation_key,
        verified => ($args{verify} eq 'verified' ? 1 : 0), 
    });

    if ($args{verify} eq 'send_email') {
        my $template = read_file(path(config->{appdir}, 'views', 'register_verify_mail.tt'));
        if ($user) {
            my $url = 'http://' . request->host . "/finish_registration?uname=$args{uname}&code=$validation_key";
            my $message = ''; # template 'register_verify_mail', { url => $url };
            my $msg = MIME::Lite->new(
                From    => 'gabor@szabgab.com',
                To      => $args{email},
                Subject => 'Verify your registration to Dwimmer!',
                Data    => $message,
            );
            $msg->send;
        }
    } else {
        # set the verified bit?
    }

    return;
}


get '/manage' => sub {
    render_response 'manage';
};


get '/edit_this_page' => sub {
    my $referer = request->referer || '';
    return $referer;
    return 'edit this page';
};


###### helper methods


sub trim {  $_[0] =~ s/^\s+|\s+$//g };

sub read_file {
    my $file = shift;
    open my $fh, '<', $file or die "Could not open '$file' $!";
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}

true;

