package MarkdownSite::Manager::Controller::Root;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub get_homepage ( $c ) { $c->stash->{template} = 'homepage'; }
sub get_docs     ( $c ) { $c->stash->{template} = 'docs';     }
sub get_contact  ( $c ) { $c->stash->{template} = 'contact';  }

sub random_domain {
    my ( $hostname ) = @_;

    return sprintf( "%s.%s", 
        join("",  map { ('a'..'z',0..9)[int rand 36] } ( 0 .. 7 )),
        $hostname
    );
}

sub post_import ( $c ) {
    $c->stash->{template} = 'import';

    my $repo   = $c->stash->{form_repo}   = $c->param('repo'); 
    my $sshkey = $c->stash->{form_sshkey} = $c->param('sshkey'); 

    # Get git repo url, find out if we already have this.  If so, we are doing a refresh.
    my $site = $c->db->site( { repo => $repo } );

    if ( $site ) {
        $c->log->info( "This repo already exists -- reloading markdownsite." );

        if ( ! $site->get_build_allowance->{can_build} ) {
            $c->log->info( "This repo has exceeded the build allowance -- rejecting job." );
            $c->redirect_to( $c->url_for( 'show_status', { id => $site->id  } )->query( reject_job => 1 ) );
            return;
        }

        my $job_id = $c->minion->enqueue( build_markdownsite => [ $site->id ] => {
            notes    => { '_mds_sid_' . $site->id => 1 },
            priority => $site->build_priority,
        });
        $site->create_related( 'builds', { job_id => $job_id } );
        $c->redirect_to( $c->url_for( 'show_status', { id => $site->id  } ) );
        return;
    }

    $c->log->info( "This is a new repo -- setting up." );

    # Create the DB record for the website.
    $c->db->storage->schema->txn_do( sub {
        my $domain = random_domain('markdownsite.net');

        # If this domain exists, try to make it again.
        while ( $c->db->site( { domain => $domain  } ) ) {
            $domain = random_domain('markdownsite.net');
        }

        $site = $c->db->sites->create({
            repo   => $repo,
            domain => $domain,
            ( $sshkey ? ( sshkey => $sshkey ) : () ),
        });
    });
    

    # Send off the job to import the markdownsite.
    my $id = $c->minion->enqueue( build_markdownsite => [ $site->id ] => { 
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });
    
    # Create a build record in the database for the site.
    $site->create_related( 'builds', { job_id => $id } );

    $c->redirect_to( $c->url_for( 'show_status', { id => $site->id  } ) );

}

sub get_status ( $c ) {
    $c->stash->{template} = 'status';

    # The repo the user asked for the status of.
    my $site_id   = $c->stash->{site_id}   = $c->param('id'); 
    
    # Find the website DB record.
    my $site = $c->stash->{site} = $c->db->site( $site_id );
    
    # If we do not have a record of this website, throw an error and return.
    if ( ! $site ) {
        $c->log->info( "No markdownsite found." );
        return;
    }

    # Display the status records.
}

1;
