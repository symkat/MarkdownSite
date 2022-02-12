package MarkdownSite::CGI;
use Mojo::Base 'Mojolicious', -signatures;
use File::Slurper qw( read_text );
use Markdown::Compiler;
use Mojo::File;
use Cwd qw( getcwd );
use Cache::Memcached::Fast;

sub startup ($self) {

    my $domain = $ENV{HTTP_HOST};

    # Load config from the given domain url...
    $self->plugin('NotYAMLConfig', { file => "/var/www/$domain/config.yml" });


    my $mem = Cache::Memcached::Fast->new({
        servers   => [ { address => '127.0.0.1:11211' } ],
        namespace => "$domain/",
    });

    $self->log->info( "Trying to load routes from memcached." );
    my %route_info = %{ $mem->get( 'routes' ) || {} };

    if ( ! %route_info ) {
        $self->log->info( "Building routes and storing them in memcached." );
        foreach my $file ( Mojo::File->new("/var/www/$domain/pages")->list_tree->each  ) {
            my $md = Markdown::Compiler->new( source => $file->slurp );

            # Now we figure out the slug for this page:

            # 1. If we have the key 'web.path' we will use that
            # 2. From the file, for each config up, does web.path.format exist?
            #       YES: Use this format to create slugs from the path name
            #       NO : Continue
            # 3. Finally, use the filename itself, switching md -> html
            if ( $md->metadata->{'web.path'} ) {
                $route_info{$md->metadata->{'web.path'}} = $file->path;
                next;
            }
        };
        $mem->set( 'routes', \%route_info );
    } else {
        $self->log->info( "Loaded routes from memcached." );
    }

    # Store all end points in a database file for quick recall next time.
    # url => path HASH with storable or something like that.  Tied hash.

    # Levels of config:
    # Root      - Owners by me / enable template directories and such
    # Directory - Owned by the user, control globals for this directory, passes to the template
    # File      - Owned by the user, passes to the template

    # Store the file in html/ for even faster next time.

    # Serve the file

    $self->renderer->paths( [qw( /var/www/themes )] );

    # Create $self->set_template
    #$self->helper( set_template => sub ($c, $name) {
    #    $c->stash->{template} = sprintf( "%s/%s", ( $c->config->{template} || 'default' ), $name );
    #});


    # Get the router.
    my $router = $self->routes;

    foreach my $route_path ( keys %route_info ) {
        $router->get($route_path)->to( cb => sub ($c) {
            my $content = Mojo::File->new( $route_info{$route_path} )->slurp;
            my $md = Markdown::Compiler->new( source => $content );

            $c->stash->{md} = {
                %{$md->metadata},
                body   => $md->result,
                source => $content,
            };

            $c->stash->{template} = 'default/page';
        });
    }
}

1;
