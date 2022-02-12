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
        run3( ['git', 'clone', $build->site->repo, "$build_dir/src" ], \undef, \my $out, \my $err );
        foreach my $line ( split /\n/, $out ) {
            $build->create_related( 'build_logs', { event  => 'info:ansible', detail => $line } );
        }
        foreach my $line ( split /\n/, $err ) {
            # TODO: Cause common errors and then make sure I catch and report them to the user.
            $build->create_related( 'build_logs', { event  => 'warn:ansible', detail => $line } );
        }

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
	    foreach my $line ( split /\n/, $out ) {
                $build->create_related( 'build_logs', { event  => 'info:ansible', detail => $line } );
            }
	    foreach my $line ( split /\n/, $err ) {
                $build->create_related( 'build_logs', { event  => 'warn:ansible', detail => $line } );
            }
        }

        $build->is_deploy_complete(1);
        $build->update;

        $build->create_related( 'build_logs', { event  => 'status:info', detail => 'finished', });

        # Delete the build directory.
        $build->is_complete(1);
        $build->update;
    });
};

1;
