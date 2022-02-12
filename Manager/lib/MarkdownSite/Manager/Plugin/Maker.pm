package MarkdownSite::Manager::Plugin::Maker;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Minion;
use Mojo::File qw( curfile );
use File::Copy::Recursive qw( dircopy );
use IPC::Run3;
use YAML;

sub register ( $self, $app, $config ) {

    $app->minion->add_task( build_markdownsite => sub ( $job, $site_id ) {
        # Make a build directory $temp_dir/build, create a build for it.
        my $build_dir = Mojo::File->tempdir( 'build-XXXXXX', CLEANUP => 0 );
        $build_dir->child('build')->make_path;
        
        my $site = $job->app->db->site( $site_id );

        my $build = $site->create_related( 'builds', {
            build_dir => $build_dir->to_string,
        });

        #==
        # Clone Repo
        #==
        run3( ['git', 'clone', $build->site->repo, "$build_dir/src" ], \undef, \undef, \undef );

        # TODO: Cause common errors and then make sure I catch and report them to the user.

        $build->is_clone_complete(1);
        $build->update;


        #==
        # Build Static Files For Webroot
        #==
        # Have a config option to change where the webroot is.
        if ( -d "$build_dir/src/webroot" ) {
            dircopy( "$build_dir/src/webroot", "$build_dir/build/html" );
            $build->create_related( 'build_logs', {
                event  => 'make_static',
                detail => 'created static directory from webroot/',
            });
        }
        

        #==
        # Build Markdown Page Store
        #==
        chdir $build->build_dir;
        # Have a config option to change where the pages are.
        if ( -d "$build_dir/src/site" ) {
            dircopy( "$build_dir/src/site", "$build_dir/build/pages" );
            $build->create_related( 'build_logs', {
                event  => 'make_pages',
                detail => 'created pages directory from site/',
            });
        }


        #==
        # Build Site Config
        #==
        Mojo::File->new($build_dir)->child('build')->child('site.yml')->spurt(
            YAML::Dump({
                domain  => $build->site->domain,
                www_dir => "$build_dir/build/",
            })
        );

        $build->is_build_complete(1);
        $build->update;
        
        # Go to the build directory and make $build_dir/.
        $ENV{MARKDOWNSITE_CONFIG} = Mojo::File->new($build->build_dir)->child('build')->child('site.yml');

        foreach my $deploy_address ( @{$job->app->config->{deploy_addresses}} ) {
            run3( ['ansible-playbook', '-i', $deploy_address, '/etc/ansible/deploy-website.yml' ], \undef, \my $out, \my $err );
            $build->create_related( 'build_logs', {
                event  => 'deploy_build',
                detail => 'ran ansible deployment',
                extra  => {
                    host   => $deploy_address,
                    stdout => $out,
                    stderr => $err,
                },
            });
        }
        
        $build->is_deploy_complete(1);
        $build->update;

        $build->create_related( 'build_logs', {
            event  => 'deploy_build',
            detail => 'finished',
        });

        # Delete the build directory.
        $build->is_complete(1);
        $build->update;
    });



    #==
    # Tasks to build a Markdown Website - For The Builder
    #==
    $app->minion->add_task( create_build => sub ( $job, $site_id ) {
        # Make a build directory $temp_dir/build, create a build for it.
        my $build_dir = Mojo::File->tempdir( 'build-XXXXXX', CLEANUP => 0 );
        $build_dir->child('build')->make_path;
        
        my $site = $job->app->db->site( $site_id );

        my $build = $site->create_related( 'builds', {
            build_dir => $build_dir->path,
        });

        $build->create_related( 'build_logs', {
            event  => 'create_build',
            detail => 'Build started',
        });

        $app->minion->enqueue( clone_repo => [ $build->id ] );

    });

    $app->minion->add_task( clone_repo => sub ( $job, $build_id ) {
        # Go to the build directory and try to checkout the repo into $build_dir/src
        my $build = $job->app->db->build( $build_id );

        chdir $build->build_dir;
        run3( ['git', 'clone', $build->site->repo, 'src' ], \undef, \undef, \undef );

        # TODO: Cause common errors and then make sure I catch and report them to
        # the user.

        $build->is_clone_complete(1);
        $build->update;
        
        $app->minion->enqueue( make_static => [ $build_id ] );
    });
            
    $app->minion->add_task( make_static  => sub ( $job, $build_id ) {
        # Go to the build directory and pull $build_dir/src/html into build_dir,
        # and ensure that the files aren't too big (5mib?).
        my $build = $job->app->db->build( $build_id );
        my $path  = curfile->path;

        $build->create_related( 'build_logs', {
            event  => 'make_static',
            detail => 'started',
        });

        chdir $build->build_dir;
        # Have a config option to change where the webroot is.
        if ( -d "src/webroot" ) {
            dircopy( 'src/webroot', 'build/html' );
            $build->create_related( 'build_logs', {
                event  => 'make_static',
                detail => 'created static directory from webroot/',
            });
        }
        
        $app->minion->enqueue( make_pages => [ $build_id ] );

    });
    
    $app->minion->add_task( make_pages  => sub ( $job, $build_id ) {
        # Go to the build directory and pull $build_dir/src/pages into build_dir.
        my $build = $job->app->db->build( $build_id );

        $build->create_related( 'build_logs', {
            event  => 'make_pages',
            detail => 'started',
        });

        chdir $build->build_dir;
        # Have a config option to change where the pages are.
        if ( -d "src/site" ) {
            dircopy( 'src/site', 'build/pages' );
            $build->create_related( 'build_logs', {
                event  => 'make_pages',
                detail => 'created pages directory from site/',
            });
        }

        $build->create_related( 'build_logs', {
            event  => 'make_pages',
            detail => 'finished',
        });
        
        $app->minion->enqueue( make_site_config => [ $build_id ] );
    });
    
    $app->minion->add_task( make_site_config  => sub ( $job, $build_id ) {
        # Go to the build directory and make $build_dir/.
        my $build = $job->app->db->build( $build_id );

        $build->create_related( 'build_logs', {
            event  => 'make_site_config',
            detail => 'started',
        });

        Mojo::File->new($build->build_dir)->child('build')->child('site.yml')->spurt(
            YAML::Dump({
                domain => $build->site->domain,
                www_dir => $build->build_dir,
            })
        );

        $build->create_related( 'build_logs', {
            event  => 'make_site_config',
            detail => 'finished',
        });

        $build->is_build_complete(1);
        $build->update;
        
        $app->minion->enqueue( deploy_build => [ $build_id ] );

    });
    
    $app->minion->add_task( deploy_build => sub ( $job, $build_id ) {
        # Go to the build directory and make $build_dir/.
        my $build = $job->app->db->build( $build_id );
        chdir '/home/manager/MarkdownSite/Ansible';
        $ENV{MARKDOWNSITE_CONFIG} = Mojo::File->new($build->build_dir)->child('build')->child('site.yml');

        $build->create_related( 'build_logs', {
            event  => 'deploy_build',
            detail => 'started',
        });

        foreach my $deploy_address ( @{$job->app->config->{deploy_addresses}} ) {
            run3( ['ansible-playbook', '-i', $deploy_address, './deploy-website.yml' ], \undef, \my $out, \my $err );
            $build->create_related( 'build_logs', {
                event  => 'deploy_build',
                detail => 'ran ansible deployment',
                extra  => {
                    host   => $deploy_address,
                    stdout => $out,
                    stderr => $err,
                },
            });
        }
        
        $build->is_deploy_complete(1);
        $build->update;

        $build->create_related( 'build_logs', {
            event  => 'deploy_build',
            detail => 'finished',
        });
    });

    # TODO make this run....
    $app->minion->add_task( cleanup_build => sub ( $job, $build_id ) {
        # Go to the build directory and make $build_dir/.
        my $build = $job->app->db->build( $build_id );

        # Delete the build directory.
        $build->is_complete(1);
        $build->update;
    });
}

1;
