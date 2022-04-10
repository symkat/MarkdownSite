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
    my $id = $c->minion->enqueue( build_markdownsite => [ $site->id ] => { 
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });
    
    # Create a build record in the database for the site.
    $site->create_related( 'builds', { job_id => $id } );

    $c->redirect_to( $c->url_for( 'show_status', { id => $site->id  } ) );

}

sub random_domain {
    my ( $hostname ) = @_;

    return sprintf( "%s.%s",
        join("",  map { ('a'..'z',0..9)[int rand 36] } ( 0 .. 7 )),
        $hostname
    );
}

1;
