package MarkdownSite::Panel::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Try::Tiny;
use DateTime;

sub show_register ( $c ) {

}

sub do_register ( $c ) {
    $c->stash->{template} = 'auth/register';
    
    my $name      = $c->stash->{form_name}             = $c->param('name');
    my $email     = $c->stash->{form_email}            = $c->param('email');
    my $password  = $c->stash->{form_password}         = $c->param('password');
    my $p_confirm = $c->stash->{form_password_confirm} = $c->param('password_confirm');

    push @{$c->stash->{errors}}, "Name is required"             unless $name;
    push @{$c->stash->{errors}}, "Email is required"            unless $email;
    push @{$c->stash->{errors}}, "Password is required"         unless $password;
    push @{$c->stash->{errors}}, "Confirm Password is required" unless $p_confirm;

    return if $c->stash->{errors};

    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $p_confirm eq $password;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($password) >= 8;
    
    return if $c->stash->{errors};

    my $person = try {
        $c->db->storage->schema->txn_do( sub {
            my $person = $c->db->resultset('Person')->create({
                email => $c->param('email'),
                name  => $c->param('name'),
            });
            $person->new_related('auth_password', {})->set_password($c->param('password'));
            return $person;
        });
    } catch {
        push @{$c->stash->{errors}}, "Account could not be created: $_";
        return;
    };

    $c->session->{uid} = $person->id;

    $c->redirect_to( $c->url_for( 'dashboard' ) );
}

sub show_login ( $c ) {

}

sub do_login ( $c ) {
    $c->stash->{template} = 'auth/login';

    my $email    = $c->stash->{form_email}    = $c->param('email');
    my $password = $c->stash->{form_password} = $c->param('password');

    my $person = $c->db->resultset('Person')->find( { email => $email } )
        or push @{$c->stash->{errors}}, "Invalid email address or password.";

    return 0 if $c->stash->{errors};

    $person->auth_password->check_password( $password )
        or push @{$c->stash->{errors}}, "Invalid email address or password.";
    
    return 0 if $c->stash->{errors};

    $c->stash->{person} = $person;

    $c->session->{uid} = $person->id;
    
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

sub do_logout ( $c ) {
    undef $c->session->{uid};
    $c->redirect_to( $c->url_for( 'show_login' ) );
}

sub show_forgot ( $c ) { }

sub do_forgot ( $c ) {
    $c->stash->{template} = 'auth/forgot';

    my $email  = $c->stash->{form_email} = $c->param('email');
    
    my $person = $c->db->resultset('Person')->find( { email => $email } )
        or push @{$c->stash->{errors}}, "There is no account with that email address.";

    return 0 if $c->stash->{errors};

    # Make a token & send the email TODO
    my $token = $person->create_auth_token;
    $c->minion->enqueue( 'send_email', [ 'forgot_password.mkit', { 
        send_to => $email, 
        link => "https://" . $c->config->{domain} . "/reset/$token",
    }]);

    # Let the user know the next steps.
    $c->stash->{success} = 1;
    $c->stash->{success_message} = 'Please check your email for a password reset link.';;

    # Clear the form.
    $c->stash->{form_email} = '';
}

sub show_reset ( $c ) { }

sub do_reset ( $c ) {
    $c->stash->{template} = 'auth/reset'; 

    my $token    = $c->param('token');
    my $password = $c->stash->{form_password}         = $c->param('password');
    my $confirm  = $c->stash->{form_password_confirm} = $c->param('password_confirm');
    
    push @{$c->stash->{errors}}, "Password is required"         unless $password;
    push @{$c->stash->{errors}}, "Confirm Password is required" unless $confirm;

    return if $c->stash->{errors};

    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $confirm eq $password;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($password) >= 8;
    
    return if $c->stash->{errors};

    my $lower_time = DateTime->now;
       $lower_time->subtract( minutes => 60 );

    my $record = $c->db->auth_tokens->search( {
        token      => $token,
        'me.created_at' => { '>=', $lower_time },
    }, { prefetch => 'person'  })->first;

    push @{$c->stash->{errors}}, "This token is not valid."
        unless $record;

    return 0 if $c->stash->{errors};

    # Change the user's password.
    $record->person->auth_password->update_password( $password );

    # Log the user into the account
    $c->session->{uid} = $record->person->id;

    # Delete this token.
    $record->delete;
    
    # Send them to the dashboard.
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

1;
