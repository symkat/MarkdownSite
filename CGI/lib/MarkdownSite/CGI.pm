package MarkdownSite::CGI;
use Mojo::Base 'Mojolicious', -signatures;
use File::Slurper qw( read_text );
use Markdown::Compiler;
use Mojo::File;
use Cwd qw( getcwd );
use Cache::Memcached::Fast;

sub startup ($self) {
    my $domain = $ENV{HTTP_HOST};
    my $r_path = $ENV{PATH_INFO};

    # Load config from the given domain url...
    $self->plugin('NotYAMLConfig', { file => "/var/www/$domain/config.yml" });

    my $mem = Cache::Memcached::Fast->new({
        servers   => [ { address => '127.0.0.1:11211' } ],
        namespace => "$domain/",
    });

    $self->log->info( "Processing request for ${domain}${r_path}" );

    # Load Routes For Markdown Pages
    my %route_info = %{ $mem->get( 'routes' ) || {} };
    if (! %route_info ) {
        foreach my $file ( Mojo::File->new("/var/www/$domain/pages")->list_tree->each  ) {
            if ( $file->extname ne 'md' ) {
                $self->log->info( "Skipping non-markdown file " . $file->to_string );
                next;
            }

            my $md = Markdown::Compiler->new( source => $file->slurp );

            # 1. If we have the key 'web.path' we will use that
            # 2. Otherwise map the file -- without domain/pages -- and change to md -> html
            if ( $md->metadata && $md->metadata->{'web.path'} ) {
                $route_info{$md->metadata->{'web.path'}} = $file->path;
                next;
            } else {
                my $dir  = substr($file->dirname->to_string,length("/var/www/$domain/pages"));
                my $name = $file->basename;
                $name =~ s/\.md$/.html/;

                $route_info{"$dir/$name"} = $file->path;
            }
        };
        $mem->set( 'routes', \%route_info );
        $self->log->info( "Built and stored routes in memcached for $domain" );
    } else {
        $self->log->info( "Loaded routes from memcached for $domain" );
    }

    $self->renderer->paths( [qw( /var/www/themes )] );

    # Get the router.
    my $router = $self->routes;

    foreach my $route_path ( keys %route_info ) {
        $router->get($route_path)->to( cb => sub ($c) {
            my $content = Mojo::File->new( $route_info{$route_path} )->slurp;
            my $md = Markdown::Compiler->new( source => $content );

            # Stash the metadata and rendered markdown so the templates may use it.
            $c->stash->{md} = {
                %{$md->metadata || {}},
                body   => $md->result,
                source => $content,
            };

            # Set the template to use.
            my $theme    = $md->metadata ? $md->metadata->{theme}    || 'default' : 'default';
            my $template = $md->metadata ? $md->metadata->{template} || 'page'    : 'page';
            $c->stash->{template} = sprintf("%s/%s", $theme, $template );

            # Serve and cache if it's an .html file.
            if ( $r_path =~ /\.html$/ ) {
                my $html      = $c->render_to_string;
                my @filepaths = split ( /\//, $r_path );
                my $filename  = pop @filepaths;
                $c->render( data => $html, format => 'html' );
                Mojo::File->new( "/var/www/$domain/html" )->child( @filepaths )->make_path->child($filename)->spurt($html);
                return;
            }

            # Now /about /about/ / won't get cached.  If we make index.html files, they don't seem to work
            # with the url remapping when things don't exist... we could cache and send_file from here? TODO
            # Or maybe dig into lighty and see if I'm missing something....
        });
    }

    # Status - Show the domain, current routing table.
    $router->get('/mds.status')->to( cb => sub ($c) {
        my $status = {
            domain => $domain,
            routes => { map { $_ => $route_info{$_}->to_string } keys %route_info },
        };
        $c->render( json => $status );
    });

    # Flush the route -- this needs to happen when the site is rebuilt to purge memcached
    $router->post('/mds.flush')->to( cb => sub ($c) {
        $self->log->info( "Flushing routes from memcache for $domain." );
        $c->render( json => { status => $mem->delete('routes') } );
    });
}

1;
