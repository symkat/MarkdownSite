package MarkdownSite::Manager::Plugin::Maker;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Minion;
use Mojo::File qw( curfile );
use File::Copy::Recursive qw( dircopy );
use IPC::Run3;
use YAML;

sub register ( $self, $app, $config ) {

    $app->minion->add_task( remove_markdownsite => sub ( $job, $domain ) {
        $job->note( _mds_template => 'remove_markdownsite.tx' );

        my @logs;
        foreach my $deploy_address ( @{$job->app->config->{deploy_addresses}} ) {
            run3( ['ansible-playbook', '-i', $deploy_address, '--extra-vars', "domain=$domain", '/etc/ansible/purge-website.yml' ], \undef, \my $out, \my $err );
            $job->note( removed_site => 1 );

            push @logs, "Host: $deploy_address", " ";
            push @logs, "---STDOUT---", " ", split( /\n/, $out );
            push @logs, "---STDERR---", " ", split( /\n/, $err );
        }

        $job->finish( \@logs );
    });

    $app->minion->add_task( build_markdownsite => sub ( $job, $site_id ) {
        $job->note( _mds_template => 'build_markdownsite.tx' );

        my $site = $job->app->db->site( $site_id );

        die "Error: No site found for site_id: $site_id"
            unless $site;

        # Create a directory to build the markdownsite.
        #
        # build-RANDOM/
        #   /src            - Repository cloned from git.
        #   /build          -
        #   /build/html     -
        #   /build/pages    -
        #   /build/site.yml -
        #
        my $build_dir = Mojo::File->tempdir( 'build-XXXXXX', CLEANUP => 0 );
        $build_dir->child('build')->make_path;

        # Create a build record in the database for the site.
        my $build = $site->create_related( 'builds', { build_dir => $build_dir->to_string, job_id => $job->id });

        my @logs;

        #==
        # Clone Repo
        #==
        run3( ['git', 'clone', $build->site->repo, "$build_dir/src" ], \undef, \my $out, \my $err );
        push @logs, "Running: git clone " . $build->site->repo . " $build_dir/src";
        push @logs, "---STDOUT---", " ", split( /\n/, $out );
        push @logs, "---STDERR---", " ", split( /\n/, $err );

        foreach my $line ( split /\n/, $err ) {
            # TODO: Cause common errors and then make sure I catch and report them to the user.
        }

        # Load the .markdown.yml config file.
        my $repo_yaml = {};
        if ( -e "$build_dir/src/.markdownsite.yml" ) {
            push @logs, "Loading .markdownsite.yml config.";
            # TODO -- test malformed file / might need try::tiny
            $repo_yaml = YAML::LoadFile( "$build_dir/src/.markdownsite.yml" );
        }

        $repo_yaml->{webroot} ||= 'webroot';
        $repo_yaml->{site}    ||= 'site';
        $repo_yaml->{branch}  ||= 'master';
        $repo_yaml->{domain}  ||= $site->domain;

        my $settings = {
            webroot => sprintf( "%s/%s", "$build_dir/src", $repo_yaml->{webroot} ),
            site    => sprintf( "%s/%s", "$build_dir/src", $repo_yaml->{site}    ),
            branch  =>  $repo_yaml->{branch},

            ( $repo_yaml->{domain} ne $site->domain
                # We have a domain mismatch, the user wants to change the domain.
                ? (
                    old_domain => $site->domain,
                    domain     => $repo_yaml->{domain},
                )
                # No domain name change..
                : (
                    domain     => $site->domain,
                )
            ),
        };

        # NO $repo_yaml past this point.

        # If the branch the user's site is in is not master, switch branches.
        if ( $settings->{branch} ne 'master' ) {
            # TODO: Checkout the branch the user has their site in.

        }

        # The domain name in the user's repo is different than the site's configuration,
        # check if the user is a sponser and if so, remap their domain.
        if ( exists $settings->{old_domain} ) {
            # TODO:
            # check site.is_sponser -> return if false

            # check that domain is a valid domain -> return if false
            if ( $settings->{domain} !~ /^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$/ ) {
                $job->fail( { error => "Invalid domain name " . $settings->{domain}, logs => \@logs });
                return;
            }

            # check that no other site has this domain -> return if false
            if ( $job->app->db->site( { domain => $settings->{domain} } ) ) {
                $job->fail( { error => "Domain name " . $settings->{domain} . " is already in use.", logs => \@logs });
                return;
            }

            push @logs, sprintf("Domain name changed from %s to %s", $settings->{old_domain}, $settings->{domain} );

            $site->domain( $settings->{domain} );
            $site->update;

            # Queue a minion job to purge the current website.
            $job->app->minion->enqueue( remove_markdownsite => [ $settings->{old_domain} ] => { notes => { '_mds_sid_' . $site->id => 1 } } );

            # Queue a job to build this site, and then exit this job.
            $job->app->minion->enqueue( build_markdownsite => [ $site->id ] => { notes => { '_mds_sid_' . $site->id => 1 } });

            push @logs, "Domain name updated -- scheduling new jobs for purge/import and returning.";

            $job->finish( \@logs );
            return;
        }

        $job->note( is_clone_complete => 1 );

        #==
        # Build Static Files For Webroot
        #==
        # TODO: Use Mojo::File to iterate the files, and throw errors on exceeding file size / file count limits..
        if ( -d $settings->{webroot} ) {
            dircopy( $settings->{webroot}, "$build_dir/build/html" );
            push @logs, 'created static directory from ' . $settings->{webroot};
        }

        #==
        # Build Markdown Page Store
        #==
        chdir $build->build_dir;
        # TODO: Use Mojo::File to iterate the files, and throw errors on exceeding file count limits.
        if ( -d $settings->{site} ) {
            dircopy( $settings->{site}, "$build_dir/build/pages" );
            push @logs, 'created pages directory from ' . $settings->{site},
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

        $job->note( is_build_complete => 1 );

        # Go to the build directory and make $build_dir/.
        $ENV{MARKDOWNSITE_CONFIG} = Mojo::File->new($build->build_dir)->child('build')->child('site.yml');

        foreach my $deploy_address ( @{$job->app->config->{deploy_addresses}} ) {
            run3( ['ansible-playbook', '-i', $deploy_address, '/etc/ansible/deploy-website.yml' ], \undef, \my $out, \my $err );
            push @logs, "Running: ansible-playbook -i $deploy_address /etc/ansible/deploy-website.yml";
            push @logs, "---STDOUT---", " ", split( /\n/, $out );
            push @logs, "---STDERR---", " ", split( /\n/, $err );

        }

        $job->note( is_deploy_complete => 1 );
        $job->finish( \@logs );
    });
};

1;
