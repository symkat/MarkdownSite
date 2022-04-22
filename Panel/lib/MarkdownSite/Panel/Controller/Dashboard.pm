package MarkdownSite::Panel::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Digest::MD5 qw( md5_hex );

my @allow_settings = ( 'builder', 'webroot' );

sub do_setting ( $c ) {
    $c->stash( template => 'dashboard/website' );
    my $site_id = $c->stash->{site_id} = $c->param('site_id');
    my $site    = $c->stash->{site}    = $c->db->site( $site_id );

    my $setting = $c->param('setting');
    my $value   = $c->param('value');
    
    if ( ! $setting or ! ( grep { $_ eq $setting } @allow_settings ) ) {
        push @{$c->stash->{errors}}, "Error: Unknown setting $setting";
        return;
    }


    if ( $c->stash->{person}->id != $site->person_id ) {
        push @{$c->stash->{errors}}, "You do not have permissions to change that site.";
        return;
    }

    $site->attr( $setting, $value );

    $c->redirect_to( $c->url_for( 'show_dashboard_website', { site_id => $site->id } ) );
}


sub index ($c) {





    #    my @networks = $c->db->resultset('Network')->all();
    #    my @nodes    = $c->db->resultset('Node')->all();
    #    my @sshkeys  = $c->db->resultset('Sshkey')->all();
    #    my $notice   = $c->param('notice');
    #
    #    $c->stash(
    #        networks => \@networks,
    #        nodes    => \@nodes,
    #        sshkeys  => \@sshkeys,
    #        notice   => $notice,
    #    );
}

sub users ($c) {
    $c->stash(
        users => [ $c->db->resultset('Person')->all ],
    );
}

sub website ( $c ){
    my $site_id = $c->stash->{site_id} = $c->param('site_id');
    my $site    = $c->stash->{site}    = $c->db->site( $site_id );

    $c->stash->{hook_secret}  = md5_hex(
        $site->created_at->epoch . $c->stash->{person}->created_at->epoch 
    );

    $c->stash->{refresh_for_minion} = 1;
}

sub rebuild ( $c ) { }

sub do_rebuild ( $c ) {
    my $site_id = $c->param('site_id');
    my $site    = $c->db->site( $site_id );
    
    # Confirm this site exists.
    if ( ! $site ) {
        $c->render( 
            text   => "Error: That site does not exist.",
            status => 404,
            format => 'txt',
        );
        return;
    }

    # Confirm the user can access this site.
    if ( $c->stash->{person}->id != $site->person_id ) {
        $c->render( 
            text   => "Error: You do not have permission to that site.",
            status => 403,
            format => 'txt',
        );
        return;
    }

    if ( ! $site->get_build_allowance->{can_build} ) {
        $c->redirect_to( $c->url_for( 'show_dashboard_website', { site_id => $site->id  } )->query( reject_job => 1 ) );
        return;
    }

    
    # Queue the job to deploy the website.
    my $id = $c->minion->enqueue( $site->builder->job_name, [ $site->id ] => {
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });

    # Queue the job to deploy the website.
    #my $id = $c->minion->enqueue( 'deploy_website', [ $site->id ] => {
    #    notes    => { '_mds_sid_' . $site->id => 1 },
    #    priority => $site->build_priority,
    #});
    
    # Create a build record in the database for the site.
    $site->create_related( 'builds', { job_id => $id } );

    $c->redirect_to( $c->url_for( 'show_dashboard_website', { site_id => $site->id } ) );
}

sub do_remove ($c) {
    $c->stash( template => 'dashboard/website' );

    my $site_id = $c->stash->{site_id} = $c->param('site_id');
    my $site    = $c->stash->{site}    = $c->db->site($site_id);

    if ( ! $site ) {
        $c->render( 
            text   => "Error: That site does not exist.",
            status => 404,
            format => 'txt',
        );
        return;
    }
    
    if ( $site->person->id != $c->stash->{person}->id ) {
        $c->render( 
            text   => "Error: You do not have permission to that site.",
            status => 403,
            format => 'txt',
        );
        return;
    }

    
    $c->minion->enqueue( purge_website =>  [ $site->domain->domain ] => {
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });

    # Okay, delete the website.
    $c->db->storage->schema->txn_do( sub {
        $site->search_related('repoes')->delete;
        $site->search_related('builds')->delete;
        $site->search_related('site_attributes')->delete;
        
        # Remove the domain record as well.
        my $domain = $site->domain;

        $site->delete;
        $domain->delete;
    } );

    # Kick the user back to the dashboard.
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );

}

1;
