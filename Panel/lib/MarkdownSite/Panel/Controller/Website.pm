package MarkdownSite::Panel::Controller::Website;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create ( $c ) { }

sub domain ( $c ) {
    my $repo_id     = $c->stash->{form_repo_id}          = $c->param('repo_id');
}

sub builder ( $c ) {

}

sub do_builder ( $c ) {
    $c->stash( template => 'website/builder' );
    my $site_id = $c->stash->{site_id} = $c->param('site_id');
    my $builder = $c->stash->{builder} = $c->param('builder');

    $c->log->info( "SiteID: " . $c->param('site_id') );
    $c->log->info( "Builder: $builder" );

}


sub do_domain ( $c ) {
    $c->stash( template => 'website/domain' );

    my $domain_type = $c->stash->{form_domain_type}      = $c->param('domain_type');
    my $domain      = $c->stash->{form_owned_domain}     = $c->param('owned_domain');
    my $subdomain   = $c->stash->{form_hosted_subdomain} = $c->param('hosted_subdomain');
    my $repo_id     = $c->stash->{form_repo_id}          = $c->param('repo_id');

    my $repo_record = $c->db->repo($repo_id);

    push @{$c->stash->{errors}}, "The repo was not found."
        unless $repo_record;;

    push @{$c->stash->{errors}}, "Unknown domain type submitted."
        unless $domain_type eq 'owned' or $domain_type eq 'hosted';

    if ( $domain_type eq 'hosted' ) {
        push @{$c->stash->{errors}}, "You must enter a subdomain."
            unless $subdomain;

    } elsif ( $domain_type eq 'owned' ) {
        push @{$c->stash->{errors}}, "You must enter a domain."
            unless $domain;
    }
    
    return if $c->stash->{errors};

    $domain = $domain ? $domain : $subdomain . '.' . $c->config->{hosted_domain};

    push @{$c->stash->{errors}}, "That domain name is already in use."
        if $c->db->domain( { domain => $domain } );
    
    return if $c->stash->{errors};

    my $domain_record = $c->stash->{person}->create_related( 'domains', { 
        domain => $domain ? $domain : $subdomain
    });

    my $site_record = $c->stash->{person}->create_related( 'sites', {
        domain_id => $domain_record->id,
    });

    $repo_record->site_id( $site_record->id );
    $repo_record->update;

    # Send the user over to the build selector.
    $c->redirect_to( $c->url_for( 'show_website_builder', { site_id => $site_record->id } ) );
}

sub repo_status ( $c ) {  
    my $job_id = $c->stash->{job_id} = $c->param('job_id');
    my $job    = $c->stash->{job} = $c->minion->job( $job_id );

    if ( ( ! $job )  or ( ! $job eq 'checkout_repo' ) ) {
        $c->render( 
            text   => "Error: Job not found or not valid.",
            status => 404,
            format => 'txt',
        );
        return;
    }

    my $repo = $c->stash->{repo} = $c->db->repo( $job->args->[0] );

    if ( $repo->site_id ) {
        # This is already setup... send the user to the site page instead.
        $c->redirect_to( $c->url_for( 'show_dashboard_website', { site_id => $repo->site_id } ) );
        return;
    }

    # We can connect to the repo just fine, let the user go and setup the domain.
    if ( $job->info->{state} eq 'finished' ) {
        $c->redirect_to( $c->url_for( 'show_website_domain', { repo_id => $repo->id } ) );
        return;

    }

    # The job finished and we cannot connect to the repo.  Tell the user about it.
    if ( $job->info->{state} eq 'failed' ) {
        push @{$c->stash->{errors}}, @{$job->info->{result}{logs}};
        return;
    }

    # It's running or queued, let the user refresh this page every 5 seconds.
    $c->stash( refresh_page => 5 );
}

sub do_create ( $c ) {
    $c->stash->{template} = 'website/create';

    # Clone URL
    my $repo_url = $c->param('repo_url');

    # Credential Mode
    my $auth_method = $c->param('auth_method');

    # SSH credentials
    my $sshkey_id = $c->param('sshkey_id');

    # HTTP Basic Auth credentials
    my $hba_user = $c->param('http_basic_username');
    my $hba_pass = $c->param('http_basic_password');

    # Check for errors in the form.
    push @{$c->stash->{errors}}, 'You must provide a clone url'   unless $repo_url;
    push @{$c->stash->{errors}}, 'You must select an auth method' unless $auth_method;
    
    push @{$c->stash->{errors}}, 'You must select a valid authentication method'
        unless $auth_method =~ /^(?:none|ssh|basic)$/;

    if ( $auth_method eq 'ssh' ) {
        push @{$c->stash->{errors}}, 'You must select an SSH Key when using ssh authentication'
            unless $sshkey_id;
    }

    if ( $auth_method eq 'basic' ) {
        push @{$c->stash->{errors}}, 'You must provide a username when using basic authentication' 
            unless $hba_user;
        push @{$c->stash->{errors}}, 'You must provide a password when using basic authentication' 
            unless $hba_pass;
    }
    
    return if $c->stash->{errors};
    
    # Make sure this user has access to the ssh key id we got.
    if ( $auth_method eq 'ssh' ) {
        push @{$c->stash->{errors}}, 'You must only use ssh keys that are your own.'
            unless $c->db->ssh_key($sshkey_id)->person_id == $c->stash->{person}->id;
    }

    return if $c->stash->{errors};

    # Let's make this repo....
    my $repo = $c->db->repoes->create( { url => $repo_url } );
    
    # Update repo with ssh credentials when using ssh auth mode.
    if ( $auth_method eq 'ssh' ) {
        $repo->ssh_key_id( $sshkey_id );
        $repo->update;
    }

    # Create basic auth credentials & update repo with them when using basic auth mode
    if ( $auth_method eq 'basic' ) {
        my $auth = $c->stash->{person}->create_related( 'basic_auths', {
            username => $hba_user,
            password => $hba_pass,
        });

        $repo->basic_auth_id( $auth->id );
        $repo->update;
    }

    # Queue a job to check that we can access the repo.
    my $id = $c->minion->enqueue( checkout_repo => [ $repo->id ] );

    # Send the user to a page that will check the result of the repo access job.
    $c->redirect_to( $c->url_for( 'show_website_repo_status', { job_id => $id } ) );
}


1;
