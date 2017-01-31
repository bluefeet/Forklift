package Test::Forklift;

=head1 NAME

Test::Forklift - Test your Forklift customizations.

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use Test2::Bundle::Extended ':v1';
    use strictures 2;
    
    use Test::Forklift;
    
    my $test = Test::Forklift->new(
        plugins => \@your_plugins,
        driver => \%your_driver_args,
        scheduler => \%your_scheduler_args,
    );
    
    $test->test();
    
    # Any other tests you want to run.
    
    done_testing;

=head1 DESCRIPTION

This module provides a generalized suite of tests.  These tests verify
the fundamental contract made by L<Forklift>'s public APIs.

If you are writing a new driver, scheduler, or plugin you should ship
it with a test that runs these tests.

If you are using Forklift in your code you should have a tests which
runs these tests with all the Forkift arguments you use.  If you have
a test suite and optimally some form of CI going this test should be
run as part of it to verify that your particular setup of Forklift is
working as expected.

=cut

use Forklift;
use Test2::Bundle::Extended ':v1';
use Types::Standard -types;

my $test_leak_trace_installed;
BEGIN {
    $test_leak_trace_installed = eval { require Test::LeakTrace; 1 };
    Test::LeakTrace->import() if $test_leak_trace_installed;
    if ($ENV{RELEASE_TESTING} and !$test_leak_trace_installed) {
        die 'Test::LeakTrace must be installed when RELEASE_TESTING is set';
    }
}

use Moo;
use strictures 2;
use namespace::clean;

around BUILDARGS => sub{
    my $orig = shift;
    my $class = shift;

    my $args = $class->$orig( @_ );

    return {
        args => {
            driver    => { class=>'::Basic' },
            scheduler => { class=>'::Basic' },
            %$args,
        },
    };
};

=head1 ARGUMENTS

This class takes all the same arguments as L<Forklift>.  The arguments you pass
are just proxied to the L<Forklift> objects that are created when the tests run.

By default the driver will be set to L<Forklift::Driver::Basic> and the scheduler
to L<Forklift::Scheduler::Basic>.

=cut

has args => (
    is       => 'ro',
    isa      => HashRef,
    required => 1,
);

=head1 METHODS

=head2 test

Calls L<test_driver>, L</test_scheduler>, and L</test_manager>.
L</test_leaks> will also be called if L<Test::LeakTrace> is installed.

=cut

sub test {
    my ($self) = @_;

    $self->test_driver();
    $self->test_scheduler();
    $self->test_manager();
    $self->test_leaks() if $test_leak_trace_installed;

    return;
}

=head2 test_driver

Tests the driver.

=cut

sub test_driver {
    my ($self) = @_;

    my $lift = $self->new_manager();

    ok(1, 'dummy');

    return;
}

around test_driver => sub{
    my ($orig, $self, @args) = @_;

    subtest driver => sub{
        $self->$orig( @args );
    };

    return;
};

=head2 test_scheduler

Tests the scheduler.  These tests also excercise the driver a bit.

=cut

sub test_scheduler {
    my ($self) = @_;

    my $lift = $self->new_manager();

    ok(1, 'dummy');

    return;
}

around test_scheduler => sub{
    my ($orig, $self, @args) = @_;

    subtest scheduler => sub{
        $self->$orig( @args );
    };

    return;
};

=head2 test_manager

Tests the manager (the L<Forklift> object).  These tests also
excercise the driver and scheduler a bit.

=cut

sub test_manager {
    my ($self) = @_;

    subtest basics => sub{
        my $lift = $self->new_manager();

        my ($result1, $result2);
        $lift->do(
            sub{ return ['foo1'] },
            sub{ $result1 = shift },
        );
        $lift->do(
            sub{ die 'foo2' },
            sub{ $result2 = shift },
        );
        $lift->wait();

        ok( $result1->success(), 'ok job was successful' );
        is( $result1->data(), ['foo1'], 'ok job data was correct' );
        is( $result1->error(), undef, 'ok job has undef error' );

        ok( !$result2->success(), 'bad job failed' );
        is( $result2->data(), undef, 'bad job has undef data' );
        like( $result2->error(), qr{^foo2}, 'bad job has correct error' );
    };

    subtest recursion => sub{
        my $lift = $self->new_manager();

        my $job_id = 0;
        my @job_ids;
        my $cb_sub;

        my $run_sub = sub {
            my ($job) = @_;
            return $job->id();
        };

        my $do_sub = sub{
            $job_id++;
            $lift->do($job_id, $run_sub, $cb_sub);
        };

        $cb_sub = sub{
            my ($result) = @_;
            push @job_ids, $result->data();
            $do_sub->() if $job_id < 10;
        };

        $do_sub->();

        $lift->wait();

        is(
            \@job_ids,
            [1..10],
            'recursively ran 10 jobs',
        );
    };

    return;
}

around test_manager => sub{
    my ($orig, $self, @args) = @_;

    subtest manager => sub{
        $self->$orig( @args );
    };

    return;
};

=head2 test_leaks

Uses L<Test::LeakTrace> to verify that no unexpected leaks are produced
by a typical usage pattern of L<Forklift>.

=cut

sub test_leaks {
    my ($self) = @_;

    my $lift = $self->new_manager();

    my $result;
    $lift->do(
        sub{ return 'foo' },
        sub{ $result = shift },
    );
    $lift->wait();
}

around test_leaks => sub{
    my ($orig, $self, @args) = @_;

    # Lots of things happen at a global level the first time through, such as
    # Type::Tiny and Moo setting things up.  Let that happen and not be considered
    # a leak.
    $self->$orig( @args );

    my @leaks = Test::LeakTrace::leaked_info(sub{
        $self->$orig( @args );
        $self->$orig( @args );
    });

    # These exceptions to the rule should be investigated.
    @leaks = (
        # Try::Tiny leaks when using the Basic driver.
        grep { $_->[1] !~ m{Try/Tiny} }
        # File::Path leaks when using the Parallel::ForkManager driver.
        grep { $_->[1] !~ m{File/Path} }
        # Log::Any leaks when using the Log::Any plugin.
        grep { $_->[1] !~ m{Log/Any} }
        # mro leaks when using the Log::Any plugin.
        grep { $_->[1] !~ m{mro} }
        @leaks
    );

    is( \@leaks, [], 'no leaks' );
    if (@leaks and eval{ require Data::Dumper; 1 }) {
        diag( Data::Dumper->Dump( [\@leaks], ['$LEAKS'] ) );
    }

    return;
};

=head2 new_manager

Creates a new L<Forklift> object using L</ARGUMENTS> and returns it.
Extra arguments may be passed which will be merged with, and overwrite
those from, L</ARGUMENTS>.

=cut

sub new_manager {
    my $self = shift;

    my $extra_args = Forklift->BUILDARGS( @_ );

    return Forklift->new(
        %{ $self->args() },
        %$extra_args,
    );
}

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

