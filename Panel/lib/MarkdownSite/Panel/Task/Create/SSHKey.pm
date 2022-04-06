package MarkdownSite::Panel::Task::Create::SSHKey;
use Mojo::Base 'Minion::Job', -signatures;
use IPC::Run3;
use Mojo::File;

sub run ( $job, $person_id, $comment ) {
    
    my $person = $job->app->db->person( $person_id );

    return $job->fail( "Error: Could not find person with id $person_id" )
        unless $person;

    my $file = Mojo::File::tempfile;

    run3( [qw( ssh-keygen -t rsa -b 2048 -N ), '', '-C', $comment, '-f', "$file.key" ], undef, \my $out, \my $err );

    # Now extract the data and make a DB record...

    my $private = Mojo::File->new( $file->path . ".key"     )->slurp;
    my $public  = Mojo::File->new( $file->path . ".key.pub" )->slurp;

    my $pair = $person->create_related( 'ssh_keys', {
        title       => $comment,
        private_key => $private,
        public_key  => $public,
    });

    # Remove the keyfiles from disk.
    Mojo::File->new( $file->path . ".key"     )->remove;
    Mojo::File->new( $file->path . ".key.pub" )->remove;

    $job->finish( "Created SSH Keypair " . $pair->id  );
}

1;
