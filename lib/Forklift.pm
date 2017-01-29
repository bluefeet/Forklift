package Forklift;

=head1 NAME

Forklift - Simple parallel job processing.

=head1 SYNOPSIS

    use Forklift;
    
    my $lift = Forklift->new();
    
    $lift->do(sub{
        # do stuff
    });
    
    $lift->do(
        # job code ref
        sub{
            # do more stuff
            return $some_value;
        },
        # callback code ref
        sub {
            my ($result) = @_;
            my $some_value = $result->data();
            # do stuff after job completion
        },
    );
    
    $lift->wait(); # wait for all jobs to complete
    $lift->throw(); # throw any exceptions caught while running the jobs

=head1 DESCRIPTION

Forklift is a tool for running jobs under various drivers and schedulers.

=head1 DRIVERS

Drivers are the part of Forklift which actually run jobs.  They define a specific
interface as defined by L<Forklift::Driver> and are communicated to by schedulers.

The common driver type is one who forks off a process, runs the job, and uses some
sort of IPC to communicate the results back.  But, there is nothing about Forklift
which actually limits the job running to forking.

Available drivers include:

=over

=item *

L<Forklift::Driver::PFM> - This uses L<Parallel::ForkManager> to run jobs in
parallel.  This is the default driver if none is specified.

=item *

L<Forklift::Driver::Basic> - An in-process, blocking, driver.  Mostly useful for
testing.  Using this is effectively identical to using the C<::PFM> driver with
C<max_workers> set to C<0>.

=back

=head1 SCHEDULERS

Schedulers decide when to run jobs.  When a job is created it is passed to a scheduler,
who them decides to immediately pass the job to the driver, or defer it to later.

Available schedulers include:

=over

=item *

L<Forklift::Scheduler::Basic> - Runs jobs one at a time, FIFO style.  This is the
default scheduler if none is specified.

=item *

L<Forklift::Scheduler::Batched> - Holds on to jobs until some batch size is reached
and then sends the batch of jobs to the driver as one unit to process.

=back

=cut

use Types::Standard -types;
use Types::Common::String -types;

use Forklift::Job;
use Forklift::Result;
use Forklift::Results;

use Moo;
use strictures 2;
use namespace::clean;

use MooX::PluginKit::Consumer;

plugin_namespace 'ForkliftX';

#sub DEMOLISH {
#    my ($self) = @_;
#    $self->wait();
#    return;
#}

=head1 OPTIONAL ARGUMENTS

=head2 driver

    driver => {
        class => '::PFM',
        max_workers => 20,
    },

An object which consumes the L<Forklift::Driver> role.  A hashref may be
passed and will automatically be instantiated into a new object.  If the
hashref has the C<class> key then that class will be used instead of
C<Forklift::Driver::PFM>.

=cut

has_pluggable_object driver => (
    isa             => ConsumerOf[ 'Forklift::Driver' ],
    class_namespace => 'Forklift::Driver',
    class_arg       => 1,
    args_builder    => 1,
    default         => sub{ {} },
    default_class   => '::PFM',
);
sub _driver_build_args {
    my ($self, $args) = @_;
    $args->{results} = $self->results();
    return $args;
}

=head2 scheduler

    scheduler => {
        class => '::Batched',
        batch_size => 8,
    }

An object which consumes the L<Forklift::Scheduler> role.  A hashref may
be passed and will automatically be instantiated into a new object.  If the
hashref hsa the C<class> key then that class will be used instead of
L<Forklift::Scheduler::Basic>.

=cut

has_pluggable_object scheduler => (
    isa             => ConsumerOf[ 'Forklift::Scheduler' ],
    class_namespace => 'Forklift::Scheduler',
    class_arg       => 1,
    args_builder    => 1,
    default         => sub{ {} },
    default_class   => '::Basic',
);
sub _scheduler_build_args {
    my ($self, $args) = @_;
    $args->{driver} = $self->driver();
    return $args;
}

=head2 results

An instance of L<Forklift::Results> or a subclass of it.  Contains the results
of completed jobs.

=cut

has_pluggable_object results => (
    is              => 'ro',
    class           => 'Forklift::Results',
    class_arg       => 1,
    args_builder    => 1,
    default         => sub{ {} },
);
sub _results_build_args {
    my ($self, $args) = @_;
    $args->{result_class} = $self->result_class();
    return $args;
}

=head2 job_class

The class to construct new job objects from.  Defaults to L<Forlift::Job>.

=cut

has_pluggable_class job_class => (
    default => 'Forklift::Job',
);

=head2 result_class

The class to construct new result objects from.  Defaults to L<Forlift::Result>.

=cut

has_pluggable_class result_class => (
    default => 'Forklift::Result',
);

=head1 METHODS

=head2 do

    $lift->do( sub{ ... } );
    $lift->do( $job_sub, $callback_sub );
    $lift->do( code=>$job_sub, callback=>$callback_sub );
    $lift->do( %args );

Creates a new L</job_class> and passes it to L<Forklift::Scheduler/schedule_job>.

This method is the main entry point to running a job.

=cut

sub do {
    my $self = shift;
    my $job = $self->job_class->new( @_ );
    $self->scheduler->schedule_job( $job );
    return $job;
}

=head2 yield

    $lift->yield();

Calling this gives the L</driver> and L</scheduler> a chance to do
their jobs.  It is only necessary to call this method when there is
a long run-time between job schedules (via L</do> or otherwise) and
L</wait> calls.  Calling this is typically non-blocking, but it depends
on the driver a bit.  For example, the C<::PFM> driver is completely
not-blocking for yields, whie the C<::Basic> driver may block if there
are queued jobs waiting to run.

=cut

sub yield {
    my ($self) = @_;

    $self->driver->yield();
    $self->scheduler->run_schedule();

    return;
}

=head2 wait

    $lift->wait();

Waits for all running and pending jobs to complete.  If any job callbacks queue
more jobs then those will be waited on as well, until there are no more jobs and
all jobs have completed.

=cut

sub wait {
    my ($self) = @_;

    my $driver = $self->driver();
    my $scheduler = $self->scheduler();

    while ($scheduler->has_pending_jobs() or $driver->is_busy()) {
        $self->scheduler->force_schedule();
        $driver->wait_one();
    }

    return;
}

=head2 throw

    $lift->throw();

Looks in L<Forklift::Results/failed> and throws an exception for
any failed results found.

=cut

sub throw {
    my ($self) = @_;

    my $results = $self->failed_results();
    return if !@$results;

    die join( "\n",
        map { s{\s+$}{}r }
        map { $_->status_message() }
        @$results
    );
}

1;
__END__

=head1 EXISTING PLUGINS

Available plugins include:

=over

=item *

L<ForkliftX::LogAny> - Logs whenever jobs start and finish using L<Log::Any>.

=back

=head2 WRITING PLUGINS

Forklift's plugin system uses L<MooX::PluginKit>.  See it's documentation for an
overview, and see L</ForkliftX::LogAny> for a working example.

Plugins on CPAN are expected to exist in the C<ForkliftX::> namespace.  Only plugins
should exist in this namespace.

=head1 AUTHOR

Aran Clary Deltac <bluefeetE<64>gmail.com>

=head1 ACKNOWLEDGEMENTS

Thanks to L<ZipRecruiter|https://www.ziprecruiter.com/>
for encouraging their employees to contribute back to the open
source ecosystem.  Without their dedication to quality software
development this distribution would not exist.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

