package MarkdownSite::CGI;
use Mojo::Base 'Mojolicious', -signatures;
use File::Slurper qw( read_text );
use Markdown::Compiler;
use Mojo::File;
use Cwd qw( getcwd );

sub startup ($self) {
    my $domain = $ENV{HTTP_HOST};
    $self->renderer->paths( [qw( /var/www/themes )] );

    # Get the router.
    my $router = $self->routes;

    $router->get('/' )->to( cb => sub ($c) { $self->handle_request($c) });
    $router->get('/*')->to( cb => sub ($c) { $self->handle_request($c) });
}

sub handle_request ( $self, $c ) {
    my $domain = $ENV{HTTP_HOST};

    my $files = $self->resolve_filepaths_from_env;
    my $markdown_file = $files->{source};

    # Serve 404 error if we do not have a markdown file.
    #
    # Serve /var/www/$domain/html/404.html as content if it exists,
    # otherwise display 'File Not Found'.
    if ( ! $markdown_file ) {
        $c->res->code( 404 );
        $c->res->body( "File Not Found\n" );
        $c->res->headers->header('x-sendfile' => "/var/www/$domain/html/404.html" )
            if -e "/var/www/$domain/html/404.html";
        return;
    }

    my $content = Mojo::File->new( $markdown_file )->slurp;
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

    my $html_file = $files->{target};

    # Serve the file to the end user.
    my $html      = $c->render_to_string;
    $c->render( data => $html, format => 'html' );

    # Store file so lighttpd serves it next time.
    my @filepaths = split ( /\//, $html_file );
    my $filename  = pop @filepaths;
    Mojo::File->new( $html_file );
    Mojo::File->new( "/" )->child( @filepaths )->make_path->child($filename)->spurt($html);
    return;

}

# Requests for markdown files will respect the following routes:
#
# site.com/           -> /var/www/site.com/pages/index.md
# site.com/about      -> /var/www/site.com/pages/about.md OR /var/www/site.com/pages/about/index.md
# site.com/about.html -> /var/www/site.com/pages/about.md
# site.com/about.htm  -> /var/www/site.com/pages/about.md
#
#
# Return path to file, or "" if it doesn't exist...
#
sub resolve_filepaths_from_env ( $self ) {
    my $domain = $ENV{HTTP_HOST};
    my $r_path = $ENV{PATH_INFO};

    # Case of / /about mapping to /index.md /about/index.md
    if (  -e "/var/www/$domain/pages/" . $r_path . "/index.md" ) {
        return {
            source => "/var/www/$domain/pages/" . $r_path . "/index.md",
            target => "/var/www/$domain/html/" . $r_path . "/index.html",
        };
    }

    # Case of about.md -> /about/index.html
    if ( -e "/var/www/$domain/pages/" . $r_path . ".md" ) {
        return {
            source => "/var/www/$domain/pages/" . $r_path . ".md",
            target => "/var/www/$domain/html/" . $r_path . "/index.html",
        };
    }

    # Case of about.md -> about.html
    if ( $r_path =~ /\.html$/ ) {
        (my $base = $r_path) =~ s/\.html$//;
        if ( -e "/var/www/$domain/pages/$base.md" ) {
            return {
                source => "/var/www/$domain/pages/$base.md",
                target => "/var/www/$domain/html/$base.html",
            };
        }
    }

    # Case of about.md -> about.htm
    if ( $r_path =~ /\.htm$/ ) {
        (my $base = $r_path) =~ s/\.htm$//;
        if ( -e "/var/www/$domain/pages/$base.md" ) {
            return {
                source => "/var/www/$domain/pages/$base.md",
                target => "/var/www/$domain/html/$base.htm",
            };
        }
    }

    return {
        source => "",
        target => "",
    };
}

1;
