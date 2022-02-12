package MarkdownSite::Manager::Command::list_sites;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw( getopt );

has description => 'List websites that are configured.';
has usage       => "$0 list-sites";


sub run {
    my ( $self, @args ) = @_;

    my $sites = $self->app->db->sites->search();

    printf ( "%-4s %-32s %s\n", "ID", "Domain", "Repository" );

    while ( defined(my $site = $sites->next ) ) {
        printf( "%-4d %-32s %s\n", $site->id, $site->domain, $site->repo );
    }
}

1;
