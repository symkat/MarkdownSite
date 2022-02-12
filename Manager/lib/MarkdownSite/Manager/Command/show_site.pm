package MarkdownSite::Manager::Command::show_site;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw( getopt );

has description => 'List websites that are configured.';
has usage       => "$0 show-site <id>";


sub run {
    my ( $self, $id ) = @_;

    my $site = $self->app->db->site($id);

    if ( ! $site ) {
        print "Error: No site with id $id\n";
    }

    printf( "%15s: %s\n", 'ID',           $site->id             );
    printf( "%15s: %s\n", 'Repository',   $site->repo           );
    printf( "%15s: %s\n", 'Domain',       $site->domain         );
    printf( "%15s: %s\n", 'Build Count',  $site->builds->count  );

    print "\nBuilds --\n\n";

    my $builds = $site->builds( { }, { order_by => { -desc => 'created_at' } } );

    while ( defined(my $build = $builds->next ) ) {
        printf( "%s (build_id: %d)\n", $site->created_at->strftime( "%F %T %Z" ), $build->id);
    	my $logs = $build->build_logs( { }, { order_by => { -asc => 'created_at' } } );
        while ( defined(my $line = $logs->next ) ) {
            printf("    %-16s %s\n", $line->event, $line->detail );
        }
	print "\n";
    }
}

1;
