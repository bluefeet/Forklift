package Forklift::Scheduler;

=head1 NAME

Forklift::Scheduler - Interface role for Forklift schedulers.

=head1 SYNOPSIS

    package Forklift::Scheduler::MyScheduler;
    use Moo;
    with 'Forklift::Scheduler';
    sub has_pending_jobs { ... }
    sub clear_pending_jobs { ... }
    sub schedule_job { ... }
    sub run_schedule { ... }
    sub force_schedule { ... }

=head1 DESCRIPTION

This Moo role enforces a strict interface for L<Forklift> schedulers.

See L<Forklift::Scheduler::Basic> and L<Forklift::Scheduler::Batched>
as examples for writing new schedulers.

=head1 ATTRIBUTES

=head2 driver

This attribute is set automatically by L<Forklift/scheduler> when the scheduler
object is instantiated.  It has the same value as L<Forklift/driver>.

=head1 REQUIRED METHODS

Schedulers MUST implement these methods.

=head2 has_pending_jobs

Whether the scheduler has any pending jobs to run which have not been passed
to the L</driver> yet.

=head2 clear_pending_jobs

Clears any pending jobs which have not yet been sent to the L</driver>.

=head2 schedule_job

Take a single L<Forklift::Job> object and schedules it to be run.

=head2 run_schedule

Runs any pending jobs at the scheduler's discretion.

=head2 force_schedule

Forces the scheduler to run all pending jobs, even if the scheduler would
normally hold off on them due to internal scheduling logic.  After calling
this there still may be pending jobs as the scheduler will not schedule
jobs if the L</driver> is saturated.

=cut

use Types::Standard -types;

use Moo::Role;
use strictures 2;
use namespace::clean;

requires qw(
    has_pending_jobs
    clear_pending_jobs
    schedule_job
    run_schedule
    force_schedule
);

has driver => (
    is       => 'ro',
    isa      => ConsumerOf[ 'Forklift::Driver' ],
    required => 1,
);

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

