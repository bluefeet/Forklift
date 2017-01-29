#!/usr/bin/env perl
use Test2::Bundle::Extended ':v1';
use strictures 2;

use Test::Forklift;

Test::Forklift->new->test();

done_testing;
