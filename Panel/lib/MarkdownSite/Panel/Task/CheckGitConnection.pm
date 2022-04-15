package MarkdownSite::Panel::Task::CheckGitConnection;
use Mojo::Base 'Minion::Job', -signatures;
use IPC::Run3;
use URI;

sub run ( $job, $repo_id ) {

    my $repo = $job->app->db->repo( $repo_id );

    die "Error: No repo found for repo_id $repo_id"
        unless $repo;

    my $build_dir = Mojo::File->tempdir( 'build-XXXXXX', CLEANUP => 1 );
    
    my @logs;

    if ( $repo->ssh_key_id ) {
        my $sshkey_file = Mojo::File->tempfile;
        $sshkey_file->spurt( $repo->ssh_key->private_key )->mode( 0600 );
        $ENV{GIT_SSH_COMMAND} = 'ssh -i ' . $sshkey_file->to_strong;
        push @logs, $job->run_system_cmd( 'git', 'clone', $repo->url, "$build_dir/src" );
    } elsif ( $repo->basic_auth_id ) {
        my $checkout_url = URI->new( $repo->url );
        my ( $hba_user, $hba_pass ) = ( $repo->basic_auth->username, $repo->basic_auth->password );
        $checkout_url->userinfo( "$hba_user:$hba_pass" );

        # Supress the user's password from the job logs.
        push @logs, map {
            $_ =~ s/\Q$hba_pass\E/_password_/; $_
        } $job->run_system_cmd( 'git', 'clone', $checkout_url, "$build_dir/src" );

    } else {
        push @logs, $job->run_system_cmd( 'git', 'clone', $repo->url, "$build_dir/src" );
    }

    foreach my $line ( @logs ) {
        if ( $line =~ /^fatal: repository \'[^']+\' does not exist$/ ) {
            $job->fail( { error => "Does not seem to be a valid repository.", logs => \@logs });
            return;
        }

        if ( $line =~ /^fatal: Could not read from remote repository\.$/ ) {
            $job->fail( { error => "Error: Permission denied - Valid access and repo?", logs => \@logs });
            return;
        }
        
        if ( $line =~ /^fatal: / ) {
            $job->fail( { error => "Error: There was an unexpected fatal error.", logs => \@logs });
            return;
        }
    }
    
    $job->finish( \@logs );
}

# Run a system command with IPC::Run3 and return a pretty-print of the logs.
sub run_system_cmd {
    my ( $self, @command ) = @_;

    run3( [ @command ], \undef, \my $out, \my $err );

    my @logs;

    push @logs, "--- Running: " . join( " ", @command );
    push @logs, "> STDOUT---", " ", split( /\n/, $out );
    push @logs, "> STDERR---", " ", split( /\n/, $err );
    push @logs, "--- Finished: " . join( " ", @command );

    return @logs;
}

1;
