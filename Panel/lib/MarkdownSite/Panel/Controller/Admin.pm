package MarkdownSite::Panel::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($c) { }

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

sub do_website ( $c ) {
    my $setting = $c->param('setting');
    my $value   = $c->param('value');

    my $site_id = $c->stash->{site_id} = $c->param('site_id');
    my $site = $c->db->site( $site_id );

    if ( $site->can($setting) ) {
        $site->$setting($value);
        $site->update;
    }

    $c->redirect_to( $c->url_for( 'show_admin_website' ) );

}

1;
