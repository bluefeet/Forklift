package Forklift::Scheduler;

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
