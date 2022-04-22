package MarkdownSite::Panel::Controller::Hook;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub do_github ( $c ) {
    my $site_id   = $c->param('site_id');
    my $site      = $c->db->site( $site_id );

    # > X-GitHub-Delivery: 72d3162e-cc78-11e3-81ab-4c9367dc0958
    # > X-Hub-Signature: sha1=7d38cdd689735b008b3c702edd92eea23791c5f6
    # > X-Hub-Signature-256: sha256=d57c68ca6f92289e6987922ff26938930f6e66a2d161ef06abdf1859230aa23c
    # > User-Agent: GitHub-Hookshot/044aadd
    
    my $gh_sha1   = $c->req->headers->header('X-Hub-Signature');
    my $gh_sha256 = $c->req->headers->header('X-Hub-Signature-256');
    my $gh_token  = $c->req->headers->header('X-GitHub-Delivery');
    my $useragent = $c->req->headers->header('User-Agent');

    my $action     = $c->param('action');
    my $sender     = $c->param('sender');
    my $repository = $c->param('repository');




}

1;
