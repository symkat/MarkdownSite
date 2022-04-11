package MarkdownSite::Panel::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller', -signatures;

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

    my $site = $c->db->site( $site_id );

    $c->stash->{refresh_for_minion} = 1;

    $c->stash->{site} = $site;
}

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

    # TODO: Check build allowence

    # Queue the job to deploy the website.
    my $id = $c->minion->enqueue( 'deploy_website', [ $site->id ] => {
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });
    
    # Create a build record in the database for the site.
    $site->create_related( 'builds', { job_id => $id } );

    $c->redirect_to( $c->url_for( 'show_dashboard_website', { site_id => $site->id } ) );
}

1;
