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

    $self->helper( db => sub {
        return state $db = MarkdownSite::Panel::DB->connect($config->{database}->{markdownsite});
    });

    $self->plugin( Minion => { Pg => $self->config->{database}->{minion} } );
    $self->plugin( 'Minion::Admin' );
    $self->minion->add_task( send_email => 'MarkdownSite::Panel::Task::SendEmail' );


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



    $auth->get('/dashboard'                    )->to('Dashboard#index'        )->name('show_dashboard'    );










    #    # Controllers to handle initial user creation, login and logout.
    #    $r->get ('/auth/init'  )->to('Auth#init'        )->name('auth_init'        );
    #    $r->post('/auth/init'  )->to('Auth#create_init' )->name('create_auth_init' );
    #    $r->get ('/auth/login' )->to('Auth#login'       )->name('auth_login'       );
    #    $r->post('/auth/login' )->to('Auth#create_login')->name('create_auth_login');
    #    $r->get ('/auth/logout')->to('Auth#logout'      )->name('logout'       );
    #
    #
    #    # Controllers to create new things.
    #    $auth->get ('/create/network' )->to('Create#network'        )->name('new_network'    );
    #    $auth->post('/create/network' )->to('Create#create_network' )->name('create_network' );
    #    $auth->get ('/create/node'    )->to('Create#node'           )->name('new_node'       );
    #    $auth->post('/create/node'    )->to('Create#create_node'    )->name('create_node'    );
    #    $auth->get ('/create/sshkey'  )->to('Create#sshkey'         )->name('new_sshkey'     );
    #    $auth->post('/create/sshkey'  )->to('Create#create_sshkey'  )->name('create_sshkey'  );
    #    $auth->get ('/create/user'    )->to('Create#user'           )->name('new_user'       );
    #    $auth->post('/create/user'    )->to('Create#create_user'    )->name('create_user'    );
    #    $auth->get ('/create/password')->to('Create#password'       )->name('new_password'   );
    #    $auth->post('/create/password')->to('Create#create_password')->name('create_password');
    #
    #    # Controllers to handle deploying/adopting nodes.
    #    $auth->get ('/deploy/manual/:node_id'   )->to('Deploy#manual'          )->name('deploy_manual'   );
    #    $auth->post('/deploy/macos'             )->to('Deploy#create_macos'    )->name('create_macos'    );
    #    $auth->get ('/deploy/automatic/:node_id')->to('Deploy#automatic'       )->name('deploy_automatic');
    #    $auth->post('/deploy/automatic'         )->to('Deploy#create_automatic')->name('create_automatic');
    #
    #    # Controllers for the dashboard to view the networks.
    #    $auth->get('/dashboard'                    )->to('Dashboard#index'        )->name('dashboard'    );
    #    $auth->get('/dashboard/users'              )->to('Dashboard#users'        )->name('list_users'   );
    #    $auth->get('/dashboard/nodes'              )->to('Dashboard::Node#list'   )->name('list_nodes'   );
    #    $auth->get('/dashboard/node/:node_id'      )->to('Dashboard::Node#view'   )->name('view_node'    );
    #    $auth->get('/dashboard/networks'           )->to('Dashboard::Network#list')->name('list_networks');
    #    $auth->get('/dashboard/network/:network_id')->to('Dashboard::Network#view')->name('view_network' );
    #    $auth->get('/dashboard/sshkeys'            )->to('Dashboard::Sshkeys#list')->name('list_sshkeys' );
    #    $auth->get('/dashboard/sshkeys/:sshkey_id' )->to('Dashboard::Sshkeys#view')->name('view_sshkey'  );

}

1;
