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

        # Load the .markdown.yml config file.
        my $repo_yaml = {};
        if ( -e "$build_dir/src/.markdownsite.yml" ) {
            $build->create_related( 'build_logs', { event  => 'info', detail => "Loading .markdownsite.yml config." } );
            $repo_yaml = YAML::LoadFile( "$build_dir/src/.markdownsite.yml" ) ;
        }

        $repo_yaml->{webroot} ||= 'webroot';
        $repo_yaml->{site}    ||= 'site';
        $repo_yaml->{branch}  ||= 'master';

        my $settings = {
            webroot => sprintf( "%s/%s", "$build_dir/src", $repo_yaml->{webroot} ),
            site    => sprintf( "%s/%s", "$build_dir/src", $repo_yaml->{site}    ),
        };


        # If the branch the user's site is in is not master, switch branches.
        if ( $repo_yaml->{branch} ne 'master' ) {
            # TODO: Checkout the branch the user has their site in.

        }

        # The domain name in the user's repo is different than the site's configuration,
        # check if the user is a sponser and if so, remap their domain.
        if ( exists $repo_yaml->{domain} and $repo_yaml->{domain} ne $site->domain ) {

            my $do_reassign = 1;
            # TODO:
            # check site.is_sponser -> return if false

            # check that domain is a valid domain -> return if false
            if ( $repo_yaml->{domain} !~ /^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$/ ) {
                # Error: Invalid domain name.
                $build->create_related( 'build_logs', { event  => 'set_domain', detail => sprintf("Domain %s is invalid.", $repo_yaml->{domain}) } );
                $do_reassign = 0;
            }

            # check that no other site has this domain -> return if false

            if ( $job->app->db->site( { domain => $repo_yaml->{domain} } ) ) {
                $build->create_related( 'build_logs', { event  => 'set_domain', detail => "Domain is invalid." } );
                $do_reassign = 0;
            }

            if ( $do_reassign ) {

                $build->create_related( 'build_logs', { event  => 'set_domain',
                    detail => sprintf("Domain name changed from %s to %s", $site->domain, $repo_yaml->{domain}) }
                );

                $site->domain( $repo_yaml->{domain} );
                $site->update;

                # TODO: queue a minion job to purge the current website
                # Queue a job to build this site, and then exit this job.
                $job->app->minion->enqueue( build_markdownsite => [ $site->id ] );

                $build->create_related( 'build_logs', { event  => 'set_domain',
                    detail => "Domain name updated -- scheduling new jobs for purge/import and returning." }
                );

                # Mark all build steps as complete -- I don't like this.... why don't I like this?

                return;

            }

        }

        $build->is_clone_complete(1);
        $build->update;

        #==
        # Build Static Files For Webroot
        #==
        # TODO: Use Mojo::File to iterate the files, and throw errors on exceeding file size / file count limits..
        if ( -d $settings->{webroot} ) {
            dircopy( $settings->{webroot}, "$build_dir/build/html" );
            $build->create_related( 'build_logs', {
                event  => 'make_static',
                detail => 'created static directory from ' . $settings->{webroot},
            });
        }

        #==
        # Build Markdown Page Store
        #==
        chdir $build->build_dir;
        # TODO: Use Mojo::File to iterate the files, and throw errors on exceeding file count limits.
        if ( -d $settings->{site} ) {
            dircopy( $settings->{site}, "$build_dir/build/pages" );
            $build->create_related( 'build_logs', {
                event  => 'make_pages',
                detail => 'created pages directory from ' . $settings->{site},
            });
        }

        #==
        # Build Site Config
        #== TODO: There is two different files made here, one is done by ansible -- pick one,
        #         probably this one.
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
