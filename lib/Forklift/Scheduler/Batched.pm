package Forklift::Scheduler::Batched;

use Types::Common::Numeric -types;

use Moo;
use strictures 2;
use namespace::clean;

with 'Forklift::Scheduler';

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

    while (my $batch = $self->next_batch()) {
        $driver->run_jobs( @$batch );
    }

    my $queue = $self->queue();
    $self->clear_pending_jobs();

    $driver->run_jobs( @$queue );

    return;
}

1;
