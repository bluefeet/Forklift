package Forklift::Scheduler::Batched;

=head1 NAME

Forklift::Scheduler::Batched - Run Forklift jobs in batches.

=head1 SYNOPSIS

    use Forklift;
    my $lift = Forklift->new(
        scheduler => {
            class      => '::Batches',
            batch_size => 5,
        },
    );

=head1 DESCRIPTION

This is a scheduler for L<Forklift> which runs jobs in batches of the specified
L</batch_size> number of jobs.  This scheduler is useful when you are running
fairly micro-sized jobs where the overhead of launching a job (such as if jobs
runs in fork()s) is measurable and avoidable by running multiple jobs together.

Note that the actual batching behavior also depends on the driver you use.  For
batching to happen the driver must be designed so that calls to
L<Forklift::Driver/run_jobs> which include multiple jobs run the jobs together.
For example, the L<Forklift::Driver::Parallel::ForkManager> driver properly runs
all jobs passed to C<run_jobs> in a single forked child.

This scheduler consumes the L<Forklift::Scheduler> role and provides the full
interface as documented there.

=cut

use Types::Common::Numeric -types;

use Moo;
use strictures 2;
use namespace::clean;

with 'Forklift::Scheduler';

=head1 OPTIONAL ARGUMENTS

=head2 batch_size

How many jobs per batch.  Defaults to C<10>.

=cut

has batch_size => (
    is      => 'ro',
    isa     => PositiveInt,
    default => 10,
);

has queue => (
    is       => 'rwp',
    init_arg => undef,
    default  => sub{ [] },
);

sub next_batch {
    my ($self) = @_;

    my $queue = $self->queue();
    my $batch_size = $self->batch_size();

    return undef if @$queue < $batch_size;

    return [ splice(@$queue, 0, $batch_size) ];
}

sub has_pending_jobs {
    my ($self) = @_;
    return (@{ $self->queue() } > 0) ? 1 : 0;
}

sub clear_pending_jobs {
    my ($self) = @_;
    $self->_set_queue( [] );
    return;
}

sub schedule_job {
    my ($self, $job) = @_;
    push @{ $self->queue() }, $job;
    $self->run_schedule();
    return;
}

sub run_schedule {
    my ($self) = @_;

    my $driver = $self->driver();

    while (!$driver->is_saturated()) {
        my $batch = $self->next_batch();
        return if !$batch;
        $driver->run_jobs( @$batch );
    }

    return;
}

sub force_schedule {
    my ($self) = @_;

    my $driver = $self->driver();

    $self->run_schedule();
    return if $driver->is_saturated();

    my $queue = $self->queue();
    return if !@$queue;

    $self->clear_pending_jobs();
    $driver->run_jobs( @$queue );

    return;
}

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

