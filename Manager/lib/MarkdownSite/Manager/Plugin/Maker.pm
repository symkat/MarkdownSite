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

        my @logs = $self->run_system_cmd(
            'ansible-playbook', '--extra-vars', "domain=$domain", '/etc/ansible/purge-website.yml'
        );

        $job->note( removed_site => 1 );

        $job->finish( \@logs );
    });

    $app->minion->add_task( build_markdownsite => 'MarkdownSite::Manager::Task::Builder' );
};

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
