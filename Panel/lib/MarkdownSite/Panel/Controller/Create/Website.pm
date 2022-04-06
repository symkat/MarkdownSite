package MarkdownSite::Panel::Controller::Create::Website;
use Mojo::Base 'Mojolicious::Controller', -signatures;


sub start ( $c ) { }

sub do_start ( $c ) {
    $c->stash->{template} = 'create/website/start';

    my $repo_url  = $c->stash->{form_repo_url}  = $c->param('repo_url');
    my $sshkey_id = $c->stash->{form_sshkey_id} = $c->param('sshkey_id');


}

1;
