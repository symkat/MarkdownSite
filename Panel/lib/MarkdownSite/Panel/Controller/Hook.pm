package MarkdownSite::Panel::Controller::Hook;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Digest::SHA qw(hmac_sha256_hex hmac_sha1_hex);
use Digest::MD5 qw( md5_hex );

sub do_github ( $c ) {
    my $site_id   = $c->param('site_id');
    my $site      = $c->db->site( $site_id );
        
    # No such website.
    return $c->render( text => "Error: No site found by that id.", status => 403, format => 'txt' )
        unless $site;

    my $content = $c->req->body;
    my $payload = $c->req->json;
    my $sha256  = $c->req->headers->header('X-Hub-Signature-256');
    my $sha1    = $c->req->headers->header('X-Hub-Signature');

    my $secret  = md5_hex(
        $site->created_at->epoch . $site->person->created_at->epoch 
    );

    # No request body for content/payload recieved.
    return $c->render( text => "No request body found.", status => 403, format => 'txt' )
        unless $content;
    
    # Expected header missing.
    return $c->render( text => "No X-Hub-Signature header found.", status => 403, format => 'txt' )
        unless $sha1;
    
    # Expected header missing.
    return $c->render( text => "No X-Hub-Signature-256 header found.", status => 403, format => 'txt' )
        unless $sha256;

    # Mismatch secret for sha1 test
    my $serv_sha1 = hmac_sha1_hex($content, $secret);
    if ( "sha1=$serv_sha1" ne $sha1 ) {
        return $c->render( text => "(invalid signature) sha1 test failed.", status => 403, format => 'txt' );
    }

    # Mismatch secret for sha256 test
    my $serv_sha256 = hmac_sha256_hex($content, $secret);
    if ( "sha256=$serv_sha256" ne $sha256 ) {
        return $c->render( text => "(invalid signature) sha256 test failed.", status => 403, format => 'txt' );
    }
    
    if ( ! $site->get_build_allowance->{can_build} ) {
        return $c->render( text => "Build limit exceeded.", status => 429, format => 'txt' );
    }

    # Queue the job to deploy the website.
    my $id = $c->minion->enqueue( $site->builder->job_name, [ $site->id ] => {
        notes    => { '_mds_sid_' . $site->id => 1 },
        priority => $site->build_priority,
    });
    
    # Create a build record in the database for the site.
    $site->create_related( 'builds', { job_id => $id } );

    $c->render( text => "OK", status => 200, format => 'txt' );
}

1;
