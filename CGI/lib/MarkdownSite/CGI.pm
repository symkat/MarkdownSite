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

    $router->get('*')->to( cb => sub ($c) {
        my $markdown_file = $self->find_markdown_file_from_path;

        if ( ! $markdown_file ) {
            $c->res->body( "MarkdownSite::CGI: File Not Found\n" );
            $c->res->code( 404 );
            return;
            # Serve 404 error.
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

        my $html_file = $self->find_html_file_from_path;

        # Serve the file to the end user.
        my $html      = $c->render_to_string;
        $c->render( data => $html, format => 'html' );

        # Store file so lighttpd serves it next time.
        my @filepaths = split ( /\//, $html_file );
        my $filename  = pop @filepaths;
        Mojo::File->new( $html_file );
        Mojo::File->new( "/" )->child( @filepaths )->make_path->child($filename)->spurt($html);
        return;
    });
}

# Requests for markdown files will respect the following routes:
# site.com/           -> /var/www/site.com/pages/index.md
# site.com/about      -> /var/www/site.com/pages/about.md OR /var/www/site.com/pages/about/index.md
# site.com/about.html -> /var/www/site.com/pages/about.md
# site.com/about.htm  -> /var/www/site.com/pages/about.md
#
#
# Return path to file, or "" if it doesn't exist..

sub find_markdown_file_from_path {
    my ( $self ) = @_;

    my $domain = $ENV{HTTP_HOST};
    my $r_path = $ENV{PATH_INFO};

    # Directory Style
    if (  -e "/var/www/$domain/pages/" . $r_path . "/index.md" ) {
        return "/var/www/$domain/pages/" . $r_path . "/index.md";
    }

    # Switch .html/.htm -> .md
    $r_path =~ s/\.(html?)/.md/;

    # .html Style
    if (  -e "/var/www/$domain/pages/" . $r_path ) {
        if ( ! -d "/var/www/$domain/pages/" . $r_path ) {
            return "/var/www/$domain/pages/" . $r_path;
        }
    }

    return "";
}

sub find_html_file_from_path {
    my ( $self ) = @_;

    my $domain = $ENV{HTTP_HOST};
    my $r_path = $ENV{PATH_INFO};

    # Directory Style
    if (  -e "/var/www/$domain/pages/" . $r_path . "/index.md" ) {
        return "/var/www/$domain/html/" . $r_path . "/index.html";
    }

    # Switch .html/.htm -> .md
    my $md_path = $r_path;
    $md_path =~ s/\.(html?)/.md/;

    # .html Style
    if (  -e "/var/www/$domain/pages/" . $md_path ) {
        return "/var/www/$domain/html/" . $r_path;
    }

    return "";
}

1;
