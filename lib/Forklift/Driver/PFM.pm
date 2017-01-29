package Forklift::Driver::PFM;

use Parallel::ForkManager;
use Types::Common::Numeric -types;

use Moo;
use strictures 2;
use namespace::clean;

with 'Forklift::Driver';

my $last_id = 0;
my $max_id = 4_000_000_000;
sub _next_id {
    $last_id ++;
    $last_id = 1 if $last_id > $max_id;
    return "worker-$last_id";
}

has _worker_jobs => (
    is      => 'ro',
    default => sub{ {} },
);

sub _finish_callback {
    my ($self, $pid, $exit, $id, $signal, $core_dump, $raw_results) = @_;

    my $results = $self->results();
    my $jobs = delete $self->_worker_jobs->{$id};

    foreach my $job (@$jobs) {
        my $result = shift( @$raw_results );
        $result = $results->add_new_result(
            %$result,
            job_id => $job->id(),
        );
        $job->run_callback( $result );
    }

    return;
}

has max_workers => (
    is      => 'ro',
    isa     => PositiveOrZeroInt,
    default => 10,
);

has wait_sleep => (
    is      => 'ro',
    isa     => PositiveOrZeroNum,
    default => 1,
);

has pfm => (
    is       => 'lazy',
    init_arg => undef,
);
sub _build_pfm {
    my ($self) = @_;

    my $pfm = Parallel::ForkManager->new(
        $self->max_workers(),
    );

    $pfm->run_on_finish(sub{ $self->_finish_callback(@_) });

    $pfm->set_waitpid_blocking_sleep( $self->wait_sleep() );

    return $pfm;
}

sub is_busy {
    my ($self) = @_;
    return ($self->pfm->running_procs() > 0) ? 1 : 0;
}

sub is_saturated {
    my ($self) = @_;
    my $pfm = $self->pfm();
    return ($pfm->running_procs() < $pfm->max_procs()) ? 0 : 1;
}

sub run_jobs {
    my ($self, @jobs) = @_;

    my $id = _next_id();
    $self->_worker_jobs->{$id} = \@jobs;

    $self->pfm->start_child( $id, sub{
        my @results;

        foreach my $job (@jobs) {
            push @results, $job->run();
        }

        return \@results;
    });

    return;
}

sub yield {
    my ($self) = @_;
    $self->pfm->reap_finished_children();
    return;
}

sub wait_one {
    my ($self) = @_;
    my $pfm = $self->pfm();
    my $running_procs = $pfm->running_procs() + 0;
    return if $running_procs == 0;
    my $available_procs = $pfm->max_procs - $running_procs;
    $pfm->wait_for_available_procs( $available_procs + 1 );
    return;
}

sub wait_all {
    my ($self) = @_;
    my $pfm = $self->pfm();
    return if !$self->is_busy();
    $pfm->wait_all_children();
    return;
}

sub wait_saturated {
    my ($self) = @_;
    my $pfm = $self->pfm();
    return if !$self->is_saturated();
    $pfm->wait_for_available_procs( 1 );
    return;
}

1;
