package Forklift::Driver::Basic;

=head1 NAME

Forklift::Driver::Basic - Run blocking jobs serially.

=head1 SYNOPSIS

    use Forklift;
    my $lift = Forklift->new(
        driver => {
            class       => '::Basic',
        },
    );

=head1 DESCRIPTION

This is a driver for L<Forklift> which runs jobs in-process, blocking, and
serially.  This driver is primarly meant as a reference driver for driver
authors as well as being the default driver used in tests.

This driver consumes the L<Forklift::Driver> role and provides the full
interface as documented there.

=cut

use Types::Common::Numeric -types;

use Moo;
use strictures 2;
use namespace::clean;

with 'Forklift::Driver';

our $IN_JOB = 0;

sub is_busy {
    return 0;
}

sub is_saturated {
    return 0;
}

sub in_job {
    return $IN_JOB;
}

sub run_jobs {
    my ($self, @jobs) = @_;

    my $result_class = $self->result_class();

    foreach my $job (@jobs) {
        my $result = do {
            local $IN_JOB = 1;
            $job->run();
        };
        $result = $result_class->new(
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
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

