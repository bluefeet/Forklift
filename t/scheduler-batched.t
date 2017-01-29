#!/usr/bin/env perl
use Test2::Bundle::Extended ':v1';
use strictures 2;

use Test::Forklift;

foreach my $batch_size (1, 2, 3, 10) {
    subtest "batch_size-$batch_size" => sub{
        Test::Forklift->new(
            scheduler => {
                class      => '::Batched',
                batch_size => $batch_size,
            },
        )->test();
    };
}

done_testing;
