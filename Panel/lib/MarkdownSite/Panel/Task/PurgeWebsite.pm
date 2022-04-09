package MarkdownSite::Panel::Task::PurgeWebsite;
use Mojo::Base 'Minion::Job', -signatures;
use IPC::Run3;

sub run ( $job, $domain ) {
    $job->note( _mds_template => 'remove_markdownsite.tx' );

    my @logs = $self->run_system_cmd(
        'ansible-playbook', '--extra-vars', "domain=$domain", '/etc/ansible/purge-website.yml'
    );

    $job->note( removed_site => 1 );

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
