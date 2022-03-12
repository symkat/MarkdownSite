package MarkdownSite::Manager;
use Mojo::Base 'Mojolicious', -signatures;
use MarkdownSite::Manager::DB;

sub startup ($self) {
    $self->plugin('NotYAMLConfig', { file => '/etc/markdownsite.yml' });

    # Use Text::Xslate for template rendering.
    $self->plugin(xslate_renderer => {
        template_options => {
            syntax => 'Metakolon',
        }
    });

    # Load our custom commands.
    push @{$self->commands->namespaces}, 'MarkdownSite::Manager::Command';

    # Create $self->db as a MarkdownSite::Manager::DB connection.
    $self->helper( db => sub {
        return state $db = MarkdownSite::Manager::DB->connect($self->config->{database}->{markdownsite});
    });

    $self->plugin( Minion => { Pg => $self->config->{database}->{minion} } );
    $self->plugin( 'Minion::Admin' );
    $self->plugin( 'MarkdownSite::Manager::Plugin::Maker', { } );

    # Get the router.
    my $router = $self->routes;

    $router->get ( '/'            )->to( 'Root#get_homepage')->name('show_homepage');
    $router->get ( '/docs'        )->to( 'Root#get_docs'    )->name('show_docs'    );
    $router->get ( '/contact'     )->to( 'Root#get_contact' )->name('show_contact' );
    $router->post( '/import'      )->to( 'Root#post_import' )->name('do_import'    );
    $router->get ( '/status/:id'  )->to( 'Root#get_status'  )->name('show_status'  );

}

1;
