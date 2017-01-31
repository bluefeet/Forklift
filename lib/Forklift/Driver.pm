package Forklift::Driver;

=head1 NAME

Forklift::Driver - Interface role for Forklift drivers.

=head1 SYNOPSIS

    package Forklift::Driver::MyDriver;
    use Moo;
    with 'Forklift::Driver';
    sub is_busy { ... }
    sub is_saturated { ... }
    sub in_job { ... }
    sub run_jobs { ... }
    sub yield { ... }
    sub wait_one { ... }
    sub wait_all { ... }
    sub wait_saturated { ... }

=head1 DESCRIPTION

This Moo role enforces a strict interface for L<Forklift> drivers.

See L<Forklift::Driver::Basic> and L<Forklift::Driver::Parallel::ForkManager>
as examples for writing new drivers.

=head1 ATTRIBUTES

=head2 result_class

This attribute is set automatically by L<Forklift/driver> when the driver
object is instantiated.  It has the same value as L<Forklift/result_class>.

=head1 REQUIRED METHODS

Drivers MUST implement these methods.

=head2 is_busy

Indicates whether the driver is currently processing any jobs.

=head2 is_saturated

Indicates whether the driver has capacity to run any more jobs.

=head2 in_job

Returns true if the current state of the driver is running a job.  A driver which
forks jobs will return false if the current PID is the parent PID.

=head2 run_jobs

Accepts a list of L<Forklift::Job> objects and runs them either
immediately or in the background.  If saturated this method is expected
to block until all the passed jobs have been handled.

When a job completes the driver is expected to create a L<Forklift::Result>
object (via L</result_class>), and call L<Forklift::Job/run_callback> on the job
with the result object as the single argument.

=head2 yield

Gives the driver a chance to process any finished jobs which have not
yet been processed.

=head2 wait_one

This blocking call tells the driver to wait for "one unit" of processing
to complete before returning.  This one unit could be a single job, or a
batch of jobs, depending on how the driver and scheduler are setup.

=head2 wait_all

Waits for all currently running jobs to complete.

=head2 wait_saturated

Waits until L</is_saturated> returns false.

=cut

use Types::Standard -types;

use Moo::Role;
use strictures 2;
use namespace::clean;

requires qw(
    is_busy
    is_saturated
    in_job
    run_jobs
    yield
    wait_one
    wait_all
    wait_saturated
);

has result_class => (
    is       => 'ro',
    isa      => ClassName,
    required => 1,
);

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

