package MarkdownSite::Panel::Task::Build::Static;
use Mojo::Base 'MarkdownSite::Panel::Task', -signatures;
use Mojo::File qw( curfile );
use File::Copy::Recursive qw( dircopy );
use IPC::Run3;
use YAML;

sub run ( $job, $site_id ) {
    $job->note( _mds_template => 'build_static' );

    my $build_dir = $job->checkout_repo( $site_id );
    my $site      = $job->app->db->site( $site_id );
    
    $job->note( is_clone_complete => 1 );

    # Show the user the commit we're on.
    $job->system_command( [ 'git', '-C', $build_dir->child('src')->to_string, 'log', '-1' ] );

    $build_dir->child('build')->make_path;

    $job->process_webroot(
        $site,
        $build_dir->child('src')->child($site->attr('webroot') || 'public')->to_string,
        $build_dir->child('build')->to_string
    );

    #==
    # Build Site Config
    #== TODO: There is two different files made here, one is done by ansible -- pick one,
    #         probably this one.
    Mojo::File->new($build_dir)->child('build')->child('site.yml')->spurt(
        YAML::Dump({
            domain  => $site->domain->domain,
            www_dir => "$build_dir/build/",
        })
    );

    $job->note( is_build_complete => 1 );

    # Go to the build directory and make $build_dir/.
    $ENV{MARKDOWNSITE_CONFIG} = Mojo::File->new($build_dir->to_string)->child('build')->child('site.yml');
    $job->system_command( [ 'ansible-playbook', '/etc/ansible/deploy-website.yml' ] );


    $job->note( is_deploy_complete => 1 );
    $job->finish( );

}

1;
