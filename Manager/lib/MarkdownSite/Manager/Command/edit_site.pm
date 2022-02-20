package MarkdownSite::Manager::Command::edit_site;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw( getopt );

has description => 'Show and edit settings for a markdownsite.';
has usage       => <<"USAGE";
"$0 edit-site <search option>  [--setting value]";

This program shows information about a markdown site and allows
the settings to be edited.

Use a search option to find a site, like --domain foobar.markdownsite.net,
or --site 5 to display the settings for a given site.

Use the OPTIONS below to change settings.  When a setting is changed, the
settings line will display as green text and show the old and new setting.

Sites may be enabled or disabled as well, with --enabled and --disabled, when
these options are used appropriate minion jobs are scheduled to handle
the purge/provision process.


SEARCH

One of these options must be used to find the site to edit.

    -s --site                     | Find site by id
    -d --domain                   | Find site by domain
    -r --repo                     | Find site by repo

OPTIONS

These options can be used to change the behavior of the site.

    --max_static_file_count       | How many files a webroot may have.

    --max_static_file_size        | File size limit per file in MiB.

    --max_static_webroot_size     | Size limit for webroot filea in MiB.

    --max_markdown_file_count     | How many markdown pages a site can have.

    --minutes_wait_after_build    | How many minutes to wait, after a build has
                                  | been submitted before allowing another build
                                  | for this site.

    --builds_per_hour             | How many builds the site can have scheduled per hour.

    --builds_per_day              | How many builds the site can have scheduled per day.

    --build_priority              | Build priority the site gets for minion jobs.

    --can_change_domain           | If the site is allowed to change its domain with the
                                  | domain: option in .markdownsite.yml.
                                  |
                                  | Disallow using the --no- flag: --no-can_change_domain.

    --enabled                     | Enable a disabled site, schedule a build for it.

    --disabled                    | Purge the content of the markdownsite, disable serving http
                                  | traffic for the domain, and prevent builds for this site from
                                  | being scheduled.

USAGE

sub run {
    my ( $self, @args ) = @_;

    getopt( \@args,
        # Search for the site with these options.
        's|site:i'   => \my $id,
        'd|domain:s' => \my $domain,
        'r|repo:s'   => \my $repo,

        # Change the site with these optiopns.
        'max_static_file_count:i'    => \my $max_static_file_count,
        'max_static_file_size:i'     => \my $max_static_file_size,
        'max_static_webroot_size:i'  => \my $max_static_webroot_size,
        'max_markdown_file_count:i'  => \my $max_markdown_file_count,
        'minutes_wait_after_build:i' => \my $minutes_wait_after_build,
        'builds_per_hour:i'          => \my $builds_per_hour,
        'builds_per_day:i'           => \my $builds_per_day,
        'build_priority:i'           => \my $build_priority,
        'can_change_domain!'         => \my $can_change_domain,
        'enabled'                    => \my $enabled,
        'disabled'                   => \my $disabled,
    );

    if ( ! ( $id or $domain or $repo ) ) {
        die "Error: Must be called with one of: --site --domain --repo\n";
    }

    my $site = $self->app->db->site( $id
        ? $id
        : $domain
            ? { domain => $domain }
            : { repo   => $repo   }
    );

    if ( ! $site ) {
        die "Error: Unable to find site.\n";
    }

    my $struct = {
        max_static_file_count => {
            old => $site->max_static_file_count,
            new => $max_static_file_count,
            is_changed => defined $max_static_file_count && ( $site->max_static_file_count != $max_static_file_count ),
        },
        max_static_file_size => {
            old => $site->max_static_file_size,
            new => $max_static_file_size,
            is_changed => defined $max_static_file_size && ( $site->max_static_file_size != $max_static_file_size ),
        },
        max_static_webroot_size => {
            old => $site->max_static_webroot_size,
            new => $max_static_webroot_size,
            is_changed => defined $max_static_webroot_size && ( $site->max_static_webroot_size != $max_static_webroot_size ),
        },
        max_markdown_file_count => {
            old => $site->max_markdown_file_count,
            new => $max_markdown_file_count,
            is_changed => defined $max_markdown_file_count && ( $site->max_markdown_file_count != $max_markdown_file_count ),
        },
        minutes_wait_after_build => {
            old => $site->minutes_wait_after_build,
            new => $minutes_wait_after_build,
            is_changed => defined $minutes_wait_after_build && ( $site->minutes_wait_after_build != $minutes_wait_after_build ),
        },
        builds_per_hour => {
            old => $site->builds_per_hour,
            new => $builds_per_hour,
            is_changed => $builds_per_hour && ( $site->builds_per_hour != $builds_per_hour ),
        },
        builds_per_day => {
            old => $site->builds_per_day,
            new => $builds_per_day,
            is_changed => defined $builds_per_day && ( $site->builds_per_day != $builds_per_day ),
        },
        build_priority => {
            old => $site->build_priority,
            new => $build_priority,
            is_changed => defined $build_priority && ( $site->build_priority != $build_priority ),
        },
        can_change_domain => {
            old => $site->can_change_domain,
            new => $can_change_domain,
            is_changed => defined $can_change_domain && ( $site->can_change_domain != $can_change_domain ),
        },
    };

    print "Domain  : " . $site->domain . "\n";
    print "Repo    : " . $site->repo . "\n";
    print "Site id : " . $site->id . "\n";
    print "Created : " . $site->created_at->strftime( "%F %T" ) . "\n";
    print "Status: : " . ( $site->is_enabled ? "Enabled" : "\033[31mDisabled\033[0m" ) . "\n";
    print "\n";

    print "=" x 42 . "\n";
    printf( "%30s %5s %5s\n", "Config Value", "Old", "New" );
    print "=" x 42 . "\n";
    foreach my $key ( sort keys %$struct ) {
        if ( $struct->{$key}{is_changed} ) {
            printf( "\033[32m%30s %5d %5d\033[0m\n", $key, $struct->{$key}{old}, $struct->{$key}{new} );
            $site->$key($struct->{$key}{new});
        } else {
            printf( "%30s %5d %5d\n", $key, $struct->{$key}{old}, $struct->{$key}{old} );
        }
    }


    # Are we going to disable the domain?
    if ( $disabled  ) {
        print "=" x 42 . "\n";

        if (!  $site->is_enabled ) {
            die "Error: This site is already disabled.  No records changed.\n";
        }
        $site->is_enabled( 0 );

        # Queue a minion job to purge the current website, associate it with the site builds..
        my $remove_mds_id = $self->app->minion->enqueue( remove_markdownsite => [ $site->domain ] => {
            notes    => { '_mds_sid_' . $site->id => 1 },
            priority => $site->build_priority,
        });
        $site->create_related( 'builds', { job_id => $remove_mds_id } );

        print "Created minion job to purge markdownsite: job_id = $remove_mds_id\n";

    }

    # Emable a disabled domain.
    if ( $enabled ) {
        print "=" x 42 . "\n";
        if ( $site->is_enabled ) {
            die "Error: This site is already enabled.  No records changed.\n";
        }

        $site->is_enabled( 1 );

        # Queue a job to build this site since it has been re-enabled.
        my $build_mds_id = $self->app->minion->enqueue( build_markdownsite => [ $site->id ] => { 
            notes    => { '_mds_sid_' . $site->id => 1 },
            priority => $site->build_priority,
        });
        $site->create_related( 'builds', { job_id => $build_mds_id } );
        
        print "Created minion job to build markdownsite: job_id = $build_mds_id\n";
    }

    $site->update;
}

1;
