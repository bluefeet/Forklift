#!/usr/bin/env perl
use Test2::Bundle::Extended ':v1';
use strictures 2;

use Test::Forklift;

Test::Forklift->new(
    driver => {
        class      => '::PFM',
        wait_sleep => 0.1,
    },
)->test();

done_testing;
