package MarkdownSite::Panel::Task;
use Mojo::Base 'Minion::Job', -signatures;
use Mojo::File qw( curfile tempfile );
use YAML;
use IPC::Run3;
use URI;
use Storable qw( dclone );

# Run a system command with IPC::Run3 and return a pretty-print of the logs.
sub run_system_cmd ( $self, @command ) {

    run3( [ @command ], \undef, \my $out, \my $err );

    my @logs;

    push @logs, "--- Running: " . join( " ", @command );
    push @logs, "> STDOUT---", " ", split( /\n/, $out );
    push @logs, "> STDERR---", " ", split( /\n/, $err );
    push @logs, "--- Finished: " . join( " ", @command );

    return @logs;
}

sub system_command ( $self, $cmd, $settings = {} ){
    
    # Change the directory, if requested.
    if ( $settings->{chdir} ) {
        # Throw an error if that directory doesn't exist.
        die "Error: directory " . $settings->{chdir} . "doesn't exist."
            unless -d $settings->{chdir};

        # Change to that directory, or die with error.
        chdir $settings->{chdir}
            or die "Failed to chdir to " . $settings->{chdir} . ": $!";

        $settings->{return_chdir} = curfile->dirname->to_string;
    }

    # Run the command, capture the return code, stdout, and stderr.
    #my $ret = run3( $cmd, \undef, \my $out, \my $err );
    # Mask values we don't want exposed in the logs.
    my $masked_cmd = dclone($cmd);
    if ( ref $settings->{mask} eq 'HASH' ) {
        foreach my $key ( keys %{$settings->{mask}} ) {
            my $value = $settings->{mask}{$key};
            $masked_cmd = [ map { s/\Q$key\E/$value/g; $_ } @{$masked_cmd} ];
        }
    }

    # Log the lines
    $self->append_log( "\n\nshell> " . join( " ", @{$masked_cmd || $cmd} ) );
    my ( $out, $err );
    my $ret = run3( $cmd, \undef, sub {
        chomp $_;
        # Mask values we don't want exposed in the logs.
        if ( ref $settings->{mask} eq 'HASH' ) {
            foreach my $key ( keys %{$settings->{mask}} ) {
                my $value = $settings->{mask}{$key};
                s/\Q$key\E/$value/g;
            }
        }
        $out .= "$_\n";
        $self->append_log( "< stdout: $_" );
    }, sub {
        chomp $_;
        # Mask values we don't want exposed in the logs.
        if ( ref $settings->{mask} eq 'HASH' ) {
            foreach my $key ( keys %{$settings->{mask}} ) {
                my $value = $settings->{mask}{$key};
                s/\Q$key\E/$value/g;
            }
        }
        $err .= "$_\n";
        $self->append_log( "<<stderr: $_" );
    });

    # Check stderr for errors to fail on.
    if ( $settings->{fail_on_stderr} ) {
        my @tests = @{$settings->{fail_on_stderr}};

        while ( my $regex = shift @tests ) {
            my $reason = shift @tests;

            if ( $err =~ /$regex/ ) {
                $self->fail( $reason );
                $self->stop;
            }
        }
    }

    # Return to the directory we started in if we chdir'ed.
    if ( $settings->{return_chdir} ) {
        chdir $settings->{return_chdir}
            or die "Failed to chdir to " . $settings->{chdir} . ": $!";
    }

    return {
        stdout => $out,
        stderr => $err,
        exitno => $ret,
    };
}

sub process_webroot ( $job, $site, $source, $dest ) {

    if ( -d $source ) {

        chdir $source
            or die "Failed to chdir to $source: $!";

        $job->append_log( "\n\n--- Processing Static Files ---" );

        my $files = Mojo::File->new( $source )->list_tree;

        if ( $files->size > $site->max_static_file_count ) {
            $job->fail( "This site may have up to " . $site->max_static_file_count . " static files, however the webroot contains " . $files->size . " files.");
            $job->stop;
        }

        my $total_file_size = 0;

        foreach my $file ( $files->each ) {
            # Does file exceed size allowed?
            if ( $file->stat->size >= ( $site->max_static_file_size * 1024 * 1024 ) ) {
                $job->fail( sprintf("This site may have static files up to %d MiB, however %s exceeds this limit.",
                    $site->max_static_file_size,
                    $file->to_string
                ));
                $job->stop;
            }

            $total_file_size += $file->stat->size;

            # If the total file size exceeds the max_static_webroot_size, fail the job.
            if ( $total_file_size >= ( $site->max_static_webroot_size * 1024 * 1024 ) ) {
                $job->fail( "This site may have up to " . $site->max_static_webroot_size .
                    " MiB in static files, however the webroot exceeds this limit."
                );
                $job->stop;
            }

            Mojo::File->new( "$dest/html/" . $file->to_rel( $source )->dirname )->make_path;
            $file->move_to( "$dest/html/" . $file->to_rel( $source ) );
            $job->append_log("File Processed: " . $file->to_rel( $source ));
        }
        $job->append_log( "--- Done Processing Static Files ---" );
    }
}

sub process_markdownsite ( $job, $site, $source, $dest ) {
    if ( -d $source ) {

        chdir $source
            or die "Failed to chdir to $source: $!";

        $job->append_log( "\n\n--- Processing MarkdownSite Files ---" );

        my $files = Mojo::File->new( $source )->list_tree;

        foreach my $file ( $files->each ) {
            # Does file exceed size allowed?
            if ( $file->stat->size >= ( 256 * 1024 ) ) {
                $job->fail("MarkdownSite limits markdown files to 256 KiB.  $file exceeds that.");
                return;
            }

            Mojo::File->new( "$dest/pages/" . $file->to_rel($source)->dirname )->make_path;
            $file->move_to( "$dest/pages/" . $file->to_rel($source) );
            $job->append_log("File Processed: " . $file->to_rel( $source ));

        }
        $job->append_log( "--- Done Processing MarkdownSite Files ---" );
    }
}



sub append_log ( $self, @lines ){
    my @logs = @{$self->info->{notes}{logs} || []};
    
    push @logs, @lines;

    $self->note( logs => \@logs );
}

sub checkout_repo ( $job, $site_id ) {
    my $repo = $job->app->db->site($site_id)->repo;

    die "Error: No repo found for site_id: $site_id"
        unless $repo;

    my $build_dir = Mojo::File->tempdir( 'build-XXXXXX', CLEANUP => 0 );

    my $git_errors = [
        qr|^fatal: repository \'[^']+\' does not exist$|     => "Does not seem to be a valid repository.",
        qr|^fatal: Could not read from remote repository\.$| => "Error: Permission denied - Valid access and repo?",
        qr|^fatal: |                                         => "Error: There was an unexpected fatal error.",
    ];
    
    if ( $repo->ssh_key_id ) {
        my $sshkey_file = tempfile;
        $sshkey_file->spurt( $repo->ssh_key->private_key )->chmod( 0600 );
        $ENV{GIT_SSH_COMMAND} = 'ssh -i ' . $sshkey_file->to_string;
        $job->system_command( [ 'git', 'clone', $repo->url, "$build_dir/src" ], {
            fail_on_stderr => $git_errors,
        });

    } elsif ( $repo->basic_auth_id ) {
        my $checkout_url = URI->new( $repo->url );
        my ( $hba_user, $hba_pass ) = ( $repo->basic_auth->username, $repo->basic_auth->password );
        $checkout_url->userinfo( "$hba_user:$hba_pass" );

        # Supress the user's password from the job logs.
        $job->system_command( [ 'git', 'clone', $checkout_url, "$build_dir/src" ], {
            mask           => { $hba_pass => '_password_' },
            fail_on_stderr => $git_errors,
        });

    } else {
        $job->system_command( [ 'git', 'clone', $repo->url, "$build_dir/src" ], {
            fail_on_stderr => $git_errors,
        });
    }

    return $build_dir;
}

1;
