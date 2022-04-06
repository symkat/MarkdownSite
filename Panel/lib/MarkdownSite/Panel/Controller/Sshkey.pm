package MarkdownSite::Panel::Controller::Sshkey;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub create ( $c ) { }

sub do_import ( $c ) {
    $c->stash->{template} = 'sshkey/import';

    my $name        = $c->stash->{form_name}        = $c->param('name');
    my $public_key  = $c->stash->{form_public_key}  = $c->param('public_key');
    my $private_key = $c->stash->{form_private_key} = $c->param('private_key');



    push @{$c->stash->{errors}}, 'You must give a name for the keypair.'        unless $name;
    push @{$c->stash->{errors}}, 'You must give a private key for the keypair.' unless $private_key;
    push @{$c->stash->{errors}}, 'You must give a public key for the keypair.'  unless $public_key;

    return if $c->stash->{errors};

    $c->stash->{person}->create_related( 'ssh_keys', {
        title       => $name,
        public_key  => $public_key,
        private_key => $private_key,
    });

    # Tell the user it worked and next steps.
    $c->stash->{success} = 1;
    $c->stash->{success_message} = 'Your key was imported and now shows on the dashboard.';
    
    # Clear the form
    $c->stash->{form_name}        = '';
    $c->stash->{form_private_key} = '';
    $c->stash->{form_public_key}  = '';
}


sub do_create ( $c ) {
    $c->stash->{template} = 'sshkey/create';

    my $name = $c->stash->{form_name} = $c->param('name');

    if ( ! $name ) {
        push @{$c->stash->{errors}}, 'You must give a name for the keypair.';
        return;
    }

    $c->minion->enqueue( 'create_sshkey', [ $c->stash->{person}->id, $name ] );

    # Tell the user it worked and next steps.
    $c->stash->{success} = 1;
    $c->stash->{success_message} = 'Your key is being created, it should show up on the dashboard in a moment.';
    
    # Clear the form
    $c->stash->{form_name} = '';

}

sub do_remove ($c ) {
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );

    my $sshkey_id = $c->param('sshkey_id');

    my $sshkey = $c->db->ssh_key( $sshkey_id );

    # No SSH Key by that ID to delete.
    return unless $sshkey;

    # The user does not own the ssh key.
    return unless $sshkey->person_id == $c->stash->{person}->id;

    # Delete the ssh key.
    $sshkey->delete;
}

1;
