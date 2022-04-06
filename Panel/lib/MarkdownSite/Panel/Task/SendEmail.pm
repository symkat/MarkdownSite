package MarkdownSite::Panel::Task::SendEmail;
use Mojo::Base 'Minion::Job', -signatures;
use Email::Sender::Simple qw( sendmail );
use Email::Sender::Transport::SMTP;
use Email::MIME::Kit;

sub run ( $job, $kit_name, $template_args ) {
    
    my $mkit_path = $job->app->config->{mkit_path};
    my $transport =  Email::Sender::Transport::SMTP->new(%{$job->app->config->{smtp}});

    my $kit = Email::MIME::Kit->new({ source => "$mkit_path/$kit_name" } );

    my $email = $kit->assemble($template_args);

    sendmail( $email, { transport => $transport } );

}

1;
