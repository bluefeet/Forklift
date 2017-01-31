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
        # job id
        'foo-3',
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

=head1 DESCRIPTION

Forklift is a tool for running jobs under various drivers and schedulers.

=head1 DRIVERS

Drivers are the part of Forklift which actually run jobs.  They define a specific
interface as defined by L<Forklift::Driver> and are communicated to by schedulers.

The common driver type is one who forks off a process, runs the job, and uses some
sort of IPC to communicate the results back.  But, there is nothing about Forklift
which actually limits the job running to forking.

Drivers are configured by setting the L</driver> argument.

Available drivers include:

=over

=item *

L<Forklift::Driver::Basic> - An in-process, blocking, driver.  Mostly useful for
testing.  This is the default driver if the C<::Parallel::ForkManager> driver is
not installed.

=item *

L<Forklift::Driver::Parallel::ForkManager> - This uses L<Parallel::ForkManager> to run
jobs in parallel.  This is the default driver if it is installed.

=back

=head1 SCHEDULERS

Schedulers decide when to run jobs.  When a job is created it is passed to a scheduler,
who then decides to immediately pass the job to the driver, or defer it to later.

Schedulers are configured by setting the L</scheduler> argument.

Available schedulers include:

=over

=item *

L<Forklift::Scheduler::Basic> - Runs jobs one at a time, FIFO style.  This is the
default scheduler if none is specified.

=item *

L<Forklift::Scheduler::Batched> - Holds on to jobs until some batch size is reached
and then sends the batch of jobs to the driver as one unit to process.

=back

=head1 PLUGINS

Plugins extend the base functionality of Forklift and allow core changes to be made
to it without bulking up the core distribution with optional dependencies.

Plugins are set with the L</plugins> argument and are configured in whatever way
the plugin documents its configuration.

Available plugins include:

=over

=item *

L<Forklift::Plugin::Log::Any> - Logs whenever jobs start and finish using L<Log::Any>.

=back

=cut

use Types::Standard -types;
use Types::Common::String -types;

use Forklift::Job;
use Forklift::Result;
use Scalar::Util qw( weaken );

use Moo;
use strictures 2;
use namespace::clean;

use MooX::PluginKit::Consumer;

plugin_namespace 'Forklift::Plugin';

sub BUILD {
    my ($self) = @_;
    $self->driver();
    $self->scheduler();
    $self->job_class();
    $self->result_class();
    return;
}

=head1 OPTIONAL ARGUMENTS

=head2 driver

    driver => {
        class => '::Parallel::ForkManager',
        max_workers => 20,
    },

An object which consumes the L<Forklift::Driver> role.  A hashref may be
passed and will automatically be instantiated into a new object.  If the
hashref has the C<class> key then that class will be used instead of
the default.

Defaults to L<Forklift::Driver::Parallel::ForkManager>, if installed, or
L<Forklift::Driver::Basic>, if not.

=cut

my $default_driver = '::Basic';
$default_driver = '::Parallel::ForkManager'
    if eval { require Forklift::Driver::Parallel::ForkManager; 1 };

has_pluggable_object driver => (
    isa             => ConsumerOf[ 'Forklift::Driver' ],
    class_namespace => 'Forklift::Driver',
    class_arg       => 1,
    args_builder    => 1,
    default         => sub{ {} },
    default_class   => $default_driver,
);
sub _driver_build_args {
    my ($self, $args) = @_;
    $args->{result_class} = $self->result_class();
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
    handles         => [qw( schedule_job )],
);
sub _scheduler_build_args {
    my ($self, $args) = @_;
    $args->{driver} = $self->driver();
    # Somehow this avoids leaks... not sure why.
    # Maybe a bug in MooX::Pluginkit which is holding onto the args hash?
    weaken $args->{driver};
    return $args;
}

=head2 plugins

    plugins => ['::Log::Any'],

An arrayref of plugin module names.  If any of the plugins start with C<::> they are
assumed to be relative to the C<Forklift::Plugin::> namespace.

=cut

# This argument comes from MooX::PluginKit.

=head2 job_class

    job_class => 'MyApp::CustomJob',

The class to construct new job objects from.  Defaults to L<Forlift::Job>.

=cut

has_pluggable_class job_class => (
    default => 'Forklift::Job',
);

=head2 result_class

    result_class => 'MyApp::CustomResult',

The class to construct new result objects from.  Defaults to L<Forlift::Result>.

=cut

has_pluggable_class result_class => (
    default => 'Forklift::Result',
);

=head1 METHODS

=head2 do

    $lift->do( sub{ ... } );
    $lift->do( $job_id, sub{ ... }, sub{ ... } );
    $lift->do( \%job_args );

Creates a new L</job_class> instance and passes it to
L</schedule_job>.

This method is the main entry point to running a L<Forklift::Job>.

=cut

sub do {
    my $self = shift;

    my $job;
    if (@_==1 and ref($_[0]) eq 'HASH') {
        $job = $self->job_class->new( @_ );
    }
    else {
        my ($id, $code, $callback);
        $code = shift;
        ($id, $code) = ($code, shift) if ref($code) ne 'CODE';
        $callback = shift;
        $job = $self->job_class->new(
            defined($id) ? (id=>$id) : (),
            code => $code,
            defined($callback) ? (callback=>$callback) : (),
        );
    }

    $self->schedule_job( $job );

    return $job;
}

=head2 yield

    $lift->yield();

Calling this gives the L</driver> and L</scheduler> a chance to do
their jobs.  It is only necessary to call this method when there is
a long run-time between job schedules (via L</do> or otherwise) and
L</wait> calls.  Calling this is typically non-blocking, but it depends
on the driver a bit.  For example, the C<::Parallel::ForkManager> driver
is completely not-blocking for yields, while the C<::Basic> driver may
block if there are queued jobs waiting to run.

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

1;
__END__

=head1 PROXIED METHODS

=head2 schedule_job

See L<Forklift::Scheduler/schedule_job>.

=head1 CUSTOMIZING

See L<Forklift::Driver> for information on making your own drivers.

See L<Forklift::Scheduler> for information on making your own schedulers.

Forklift's plugin system uses L<MooX::PluginKit>.  See it's documentation for an
overview, and see L</Forklift::Plugin::Log::Any> for a working example.  Plugins
on CPAN are expected to exist in the C<Forklift::Plugin::> namespace.

Generally new drivers, schedulers, and plugins will not be allowed into the core
Forklift distribution unless that is a convincing reason to do so.  This is especially
so if the new code would introduce new CPAN dependencies.

Note that any new driver, scheduler, and plugin should at a minimum include a
test which runs the entine L<Test::Forklift> test suite.  See the tests in this
distribution for examples of how this works.  Even if your code won't exist on
CPAN, running the generic Forklift tests against your customizations is highly
encouraged.

=head1 SUPPORT

Feature requests, pull requests, and discussion can be had on GitHub at
L<https://github.com/bluefeet/Forklift>.  You are also welcome to email
the author directly.

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

