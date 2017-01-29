package Forklift::Driver::Basic;

use Types::Common::Numeric -types;

use Moo;
use strictures 2;
use namespace::clean;

with 'Forklift::Driver';

sub is_busy {
    return 0;
}

sub is_saturated {
    return 0;
}

sub run_jobs {
    my ($self, @jobs) = @_;

    my $results = $self->results();

    foreach my $job (@jobs) {
        my $result = $job->run();
        $result = $results->add_new_result(
            %$result,
            job_id => $job->id(),
        );
        $job->run_callback( $result );
    }

    return;
}

sub yield {
    return;
}

sub wait_one {
    return;
}

sub wait_all {
    return;
}

sub wait_saturated {
    return;
}

1;
