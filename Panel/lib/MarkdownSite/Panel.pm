package MarkdownSite::Panel;
use Mojo::Base 'Mojolicious', -signatures;
use MarkdownSite::Panel::DB;

sub startup ($self ) {

    # Load configuration from config file
    my $config = $self->plugin('NotYAMLConfig', { file => -e 'markdownsite.yml' 
        ? 'markdownsite.yml' 
        : '/etc/markdownsite.yml'
    });

    # Configure the application
    $self->secrets($config->{secrets});

    # Set the cookie expires to 30 days.
    $self->sessions->default_expiration(2592000);

    # Load our custom commands.
    push @{$self->commands->namespaces}, 'MarkdownSite::Panel::Command';

    $self->helper( db => sub {
        return state $db = MarkdownSite::Panel::DB->connect($config->{database}->{markdownsite});
    });

    $self->plugin( Minion => { Pg => $self->config->{database}->{minion} } );
    $self->minion->add_task( send_email     => 'MarkdownSite::Panel::Task::SendEmail'          );
    $self->minion->add_task( create_sshkey  => 'MarkdownSite::Panel::Task::Create::SSHKey'     );
    $self->minion->add_task( deploy_website => 'MarkdownSite::Panel::Task::DeployWebsite'      );
    $self->minion->add_task( purge_website  => 'MarkdownSite::Panel::Task::PurgeWebsite'       );
    $self->minion->add_task( checkout_repo  => 'MarkdownSite::Panel::Task::CheckGitConnection' );
    
    # Builders
    $self->minion->add_task( build_jekyll  => 'MarkdownSite::Panel::Task::Build::Jekyll' );
    $self->minion->add_task( build_static  => 'MarkdownSite::Panel::Task::Build::Static' );


    # Standard router.
    my $r = $self->routes->under( '/' => sub ($c)  {
        
        # If the user has a uid session cookie, then load their user account.
        if ( $c->session('uid') ) {
            my $person = $c->db->resultset('Person')->find( $c->session('uid') );
            if ( $person && $person->is_enabled ) {
                $c->stash->{person} = $person;
            }
        }

        return 1;
    });

    # Create a router chain that ensures the request is from an authenticated user.
    my $auth = $r->under( '/' => sub ($c) {
        
        # Logged in user exists.
        if ( $c->stash->{person} ) {
            return 1;
        }

        # No user account for this seession.
        $c->redirect_to( $c->url_for( 'show_login' ) );
        return undef;
    });
    
    # Create a router chain that ensures the request is from an admin user.
    my $admin = $r->under( '/' => sub ($c) {
        
        # Logged in user exists.
        if ( $c->stash->{person}->is_admin ) {
            return 1;
        }

        # No user account for this seession.
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    });

    # Add the minion dashboard for admins.
    $self->plugin( 'Minion::Admin' => { route => $admin->under('/minion'  => sub ($c) {
        return 1;
    })});

    # User registration, login, and logout.
    $r->get    ('/register' )->to('Auth#register'     )->name('show_register'  );
    $r->post   ('/register' )->to('Auth#do_register'  )->name('do_register'    );
    $r->get    ('/login'    )->to('Auth#login'        )->name('show_login'     );
    $r->post   ('/login'    )->to('Auth#do_login'     )->name('do_login'       );
    $auth->get ('/logout'   )->to('Auth#do_logout'    )->name('do_logout'      );

    # User Forgot Password Workflow.
    $r->get ('/forgot'       )->to('Auth#forgot'      )->name('show_forgot'    );
    $r->post('/forgot'       )->to('Auth#do_forgot'   )->name('do_forgot'      );
    $r->get ('/reset/:token' )->to('Auth#reset'       )->name('show_reset'     );
    $r->post('/reset/:token' )->to('Auth#do_reset'    )->name('do_reset'       );

    # Send requests for / to the dashboard.
    $r->get('/')->to(cb => sub ($c) {
        $c->redirect_to( $c->url_for('dashboard') )
    });

    # User setting changes when logged in
    $auth->get ('/profile'   )->to('UserSettings#profile'            )->name('show_profile'         );
    $auth->post('/profile'   )->to('UserSettings#do_profile'         )->name('do_profile'           );
    $auth->get ('/password'  )->to('UserSettings#change_password'    )->name('show_change_password' );
    $auth->post('/password'  )->to('UserSettings#do_change_password' )->name('do_change_password'    );

    # User dashboard
    $auth->get ('/dashboard'                            )->to('Dashboard#index'      )->name('show_dashboard'               );
    $auth->get ('/dashboard/website/:site_id'           )->to('Dashboard#website'    )->name('show_dashboard_website'       );
    $auth->post('/dashboard/website/:site_id/rebuild'   )->to('Dashboard#do_rebuild' )->name('do_dashboard_website_rebuild' );

    # User create new website
    #$auth->get  ('/create/website' )->to('Create::Website#start'   )->name('show_create_website' );
    #$auth->post ('/create/website' )->to('Create::Website#do_start')->name('do_create_website'   );

    # Manage Websites
    $auth->get  ('/website'                  )->to('Website#create'      )->name('show_create_website'      );
    $auth->post ('/website'                  )->to('Website#do_create'   )->name('do_create_website'        );
    $auth->get  ('/website/:job_id'          )->to('Website#repo_status' )->name('show_website_repo_status' );
    $auth->get  ('/website/domain/:repo_id'  )->to('Website#domain'      )->name('show_website_domain'      );
    $auth->post ('/website/domain/:repo_id'  )->to('Website#do_domain'   )->name('do_website_domain'        );
    $auth->get  ('/website/builder/:site_id' )->to('Website#builder'     )->name('show_website_builder'     );
    $auth->post ('/website/builder/:site_id' )->to('Website#do_builder'  )->name('do_website_builder'       );

    # Manage SSH Keys
    $auth->get  ('/sshkey'        )->to('Sshkey#create'   )->name('show_create_sshkey' );
    $auth->get  ('/sshkey/import' )->to('Sshkey#import'   )->name('show_import_sshkey' );
    $auth->post ('/sshkey/create' )->to('Sshkey#do_create')->name('do_create_sshkey'   );
    $auth->post ('/sshkey/import' )->to('Sshkey#do_import')->name('do_import_sshkey'   );
    $auth->post ('/sshkey/remove' )->to('Sshkey#do_remove')->name('do_remove_sshkey'   );

    # Admin Dashboard
    $admin->get ('/admin'                   )->to('Admin#index'      )->name('show_admin'           );
    $admin->get ('/admin/websites'          )->to('Dashboard#website')->name('show_admin_websiteis' );
    $admin->get ('/admin/website/:site_id'  )->to('Admin#website'    )->name('show_admin_website'   );
    $admin->post('/admin/website/:site_id'  )->to('Admin#do_website' )->name('do_admin_website'     );
    $admin->get ('/admin/person/:person_id' )->to('Dashboard#person' )->name('show_admin_person'    );
    $admin->get ('/admin/people'            )->to('Dashboard#person' )->name('show_admin_people'    );

}

1;
