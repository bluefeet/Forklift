package Forklift::Scheduler::Basic;

use Types::Common::Numeric -types;

use Moo;
use strictures 2;
use namespace::clean;

with 'Forklift::Scheduler';

has queue => (
    is       => 'rwp',
    init_arg => undef,
    default  => sub{ [] },
);

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

    my $queue = $self->queue();
    my $driver = $self->driver();

    while (@$queue) {
        last if $driver->is_saturated();
        $driver->run_jobs( shift @$queue );
    }

    return;
}

sub force_schedule {
    my ($self) = @_;

    my $queue = $self->queue();
    my $driver = $self->driver();

    while (@$queue) {
        $driver->run_jobs( shift @$queue );
    }

    return;
}

1;
