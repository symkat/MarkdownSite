package MarkdownSite::Panel::Controller::Website;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create ( $c ) { }

sub repo_status ( $c ) {  
    my $job_id = $c->stash->{job_id} = $c->param('job_id');
    my $job    = $c->stash->{job} = $c->minion->job( $job_id );

    push @{$c->stash->{errors}}, "There is no job of that id"
        unless $job;
    
    return if $c->stash->{errors};

    push @{$c->stash->{errors}}, "That is not the type of task that should be here..."
        unless $job->task eq 'checkout_repo';

    return if $c->stash->{errors};

    my $repo = $c->stash->{repo} = $c->db->repo( $job->args->[0] );

    push @{$c->stash->{errors}}, "This process already seems completed?"
        if $repo->site_id;

    # TODO - Those errors should just kick the user back... or be blank pages...
    # 
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
