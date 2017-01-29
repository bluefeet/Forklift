package Forklift::Driver;

use Types::Standard -types;

use Moo::Role;
use strictures 2;
use namespace::clean;

requires qw(
    is_busy
    is_saturated
    run_jobs
    yield
    wait_one
    wait_all
    wait_saturated
);

has results => (
    is       => 'ro',
    isa      => InstanceOf[ 'Forklift::Results' ],
    required => 1,
);

1;
