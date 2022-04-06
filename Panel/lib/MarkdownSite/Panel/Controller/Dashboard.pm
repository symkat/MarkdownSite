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

1;
