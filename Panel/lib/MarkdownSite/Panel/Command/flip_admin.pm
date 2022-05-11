package MarkdownSite::Panel::Command::flip_admin;
use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Schema::Config;

use Mojo::Util qw( getopt );

has description => "Flip a user's admin bit.";
has usage       => "$0 flip_admin email\@domain.comi\n";

sub run {
    my ( $self, $email ) = @_;

    die "Error: you must provide an email address.\n"
        unless $email;

    my $person = $self->app->db->person( { email => $email } );

    die "Error: couldn't find anyone with the email $email?\n"
        unless $person;

    if ( $person->is_admin ) {
        $person->is_admin( 0 );
        print "That account was previously an admin.  Now it is not.\n";
    } else {
        $person->is_admin( 1 );
        print "$email is now an admin.\n";
    }

    $person->update;
}

1;
