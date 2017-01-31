#!/usr/bin/env perl
use Test2::Bundle::Extended ':v1';
use strictures 2;

use Test::Forklift;

{
    package Forklift::Plugin::Test::Manager;
    use Moo::Role;
    use MooX::PluginKit::Plugin;
    plugin_applies_to 'Forklift';
    sub test_manager_plugin { }
}

{
    package Forklift::Plugin::Test::Driver;
    use Moo::Role;
    use MooX::PluginKit::Plugin;
    plugin_applies_to 'Forklift::Driver';
    sub test_driver_plugin { }
}

{
    package Forklift::Plugin::Test::Scheduler;
    use Moo::Role;
    use MooX::PluginKit::Plugin;
    plugin_applies_to 'Forklift::Scheduler';
    sub test_scheduler_plugin { }
}

{
    package Forklift::Plugin::Test::Job;
    use Moo::Role;
    use MooX::PluginKit::Plugin;
    plugin_applies_to 'Forklift::Job';
    sub test_job_plugin { }
}

{
    package Forklift::Plugin::Test::Result;
    use Moo::Role;
    use MooX::PluginKit::Plugin;
    plugin_applies_to 'Forklift::Result';
    sub test_result_plugin { }
}

{
    package Forklift::Plugin::Test;
    use Moo::Role;
    use MooX::PluginKit::Plugin;
    plugin_includes qw(
        ::Manager
        ::Driver
        ::Scheduler
        ::Job
        ::Result
    );
}

my $tester = Test::Forklift->new(
    plugins => ['::Test'],
);
$tester->test();

my $lift = $tester->new_manager();
can_ok( $lift, ['test_manager_plugin'], 'plugin was applied to the manager' );
can_ok( $lift->driver(), ['test_driver_plugin'], 'plugin was applied to the driver' );
can_ok( $lift->scheduler(), ['test_scheduler_plugin'], 'plugin was applied to the scheduler' );
can_ok( $lift->job_class(), ['test_job_plugin'], 'plugin was applied to the job class' );
can_ok( $lift->result_class(), ['test_result_plugin'], 'plugin was applied to the result class' );

done_testing;
