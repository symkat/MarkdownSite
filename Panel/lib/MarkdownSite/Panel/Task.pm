package MarkdownSite::Panel::Task;
use Mojo::Base 'Minion::Job', -signatures;
use Mojo::File qw( curfile );
use YAML;
use IPC::Run3;
use URI;

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

sub system_command ( $self, $cmd, $settings ){
    
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
    my $ret = run3( $cmd, \undef, \my $out, \my $err );

    # Mask values we don't want exposed in the logs.
    if ( ref $settings->{mask} eq 'HASH' ) {
        foreach my $key ( keys %{$settings->{mask}} ) {
            my $value = $settings->{mask}{$key};
            $cmd = [ map { s/\Q$key\E/$value/g; $_ } @{$cmd} ];
            $out =~ s/\Q$key\E/$value/g;
            $err =~ s/\Q$key\E/$value/g;
        }
    }

    # Log the lines
    $self->append_log( "\n\nshell> " . join( " ", @{$cmd} ) );
    $self->append_log( map { "< stdout: $_"  } ( split( "\n", $out ) ) );
    $self->append_log( map { "<<stderr: $_"  } ( split( "\n", $err ) ) );


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
        my $sshkey_file = Mojo::File->tempfile;
        $sshkey_file->spurt( $repo->ssh_key->private_key )->mode( 0600 );
        $ENV{GIT_SSH_COMMAND} = 'ssh -i ' . $sshkey_file->to_strong;
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
