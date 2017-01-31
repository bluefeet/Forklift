package Forklift::Scheduler::Basic;

=head1 NAME

Forklift::Scheduler::Basic - Run Forklift jobs in the order they are scheduled.

=head1 SYNOPSIS

    use Forklift;
    my $lift = Forklift->new(
        scheduler => {
            class       => '::Basic',
        },
    );

=head1 DESCRIPTION

This is a scheduler for L<Forklift> which runs jobs in the order that they are
scheduled.

This scheduler consumes the L<Forklift::Scheduler> role and provides the full
interface as documented there.

=cut

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
    return $self->run_schedule();
}

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

