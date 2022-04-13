package MarkdownSite::Panel::Controller::Create::Website;
use Mojo::Base 'Mojolicious::Controller', -signatures;


sub start ( $c ) { }

sub do_start ( $c ) {
    $c->stash->{template} = 'create/website/start';

    my $repo_url  = $c->stash->{form_repo_url}  = $c->param('repo_url');
    my $sshkey_id = $c->stash->{form_sshkey_id} = $c->param('sshkey_id');


    # Create the DB record for the website.
    my $site = $c->db->storage->schema->txn_do( sub {
        my $domain = random_domain($c->config->{hosted_domain});

        # If this domain exists, try to make it again.
        while ( $c->db->domain( { domain => $domain  } ) ) {
            $domain = random_domain($c->config->{hosted_domain});
        }

        my $domain_record = $c->stash->{person}->create_related( 'domains', { 
            domain => $domain 
        });

        my $site_record = $c->stash->{person}->create_related( 'sites', {
            domain => $domain_record,
        });

        my $repo_record = $site_record->create_related( 'repoes', {
            ssh_key_id => $sshkey_id,
            url        => $repo_url,
        });

        return $site_record;
    });
    

    # Send off the job to import the markdownsite.
    my $id = $c->minion->enqueue( deploy_website => [ $site->id ] => { 
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });
    
    # Create a build record in the database for the site.
    $site->create_related( 'builds', { job_id => $id } );

    $c->redirect_to( $c->url_for( 'show_dashboard_website', { site_id => $site->id  } ) );

}

sub do_connect ( $c ) {
    $c->stash->{template} = 'create/website/start';

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
    my $repo = $c->stash->{person}->create_related( 'repoes', { url => $repo_url } );

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

    # Send the user to the page that takes over from here.

}




sub random_domain {
    my ( $hostname ) = @_;

    return sprintf( "%s.%s",
        join("",  map { ('a'..'z',0..9)[int rand 36] } ( 0 .. 7 )),
        $hostname
    );
}

1;
