package MarkdownSite::Manager::Command::edit_site;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw( getopt );

has description => 'Edit a markdown site';
has usage       => <<"USAGE";
"$0 edit-site --site <id> [--opt value]";

OPTIONS:
    -s --site   | The ID of the markdown site to update.
    -d --domain | Update the site to use this domain.
    -r --repo   | Update the site to clone this repo.

USAGE

sub run {
    my ( $self, @args ) = @_;

    getopt( \@args,
        's|site=i'   => \my $id,
        'd|domain:s' => \my $domain,
        'r|repo:s'   => \my $repo,
    );

    die "Error: --site is required." unless $id;

    my $site = $self->app->db->site($id);

    die "Error: No site with id $id" unless $site;

    if ( $domain ) {
        printf("Updating domain from %s to %s\n", $site->domain, $domain );
        $site->domain( $domain );
        $site->update;
    }

    if ( $repo ) {
        printf("Updating repo from %s to %s\n", $site->repo, $repo );
        $site->repo( $repo );
        $site->update;
    }
}

1;
