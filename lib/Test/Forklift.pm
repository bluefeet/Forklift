package Test::Forklift;

use Forklift;
use Test2::Bundle::Extended ':v1';
use Types::Standard -types;

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

has args => (
    is       => 'ro',
    isa      => HashRef,
    required => 1,
);

sub new_manager {
    my $self = shift;

    my $extra_args = Forklift->BUILDARGS( @_ );

    return Forklift->new(
        %{ $self->args() },
        %$extra_args,
    );
}

sub test {
    my ($self) = @_;
    $self->test_manager();
    $self->test_scheduler();
    $self->test_driver();
    return;
}

around test_manager => sub{
    my ($orig, $self, @args) = @_;

    subtest manager => sub{
        $self->$orig( @args );
    };

    return;
};

sub test_manager {
    my ($self) = @_;

    subtest basics => sub{
        my $lift = $self->new_manager();

        my ($result1, $result2);
        my $job1 = $lift->do(
            code => sub{ return ['foo1'] },
            callback => sub{ $result1 = shift },
        );
        my $job2 = $lift->do(
            code => sub{ die 'foo2' },
            callback => sub{ $result2 = shift },
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
            $lift->do(id=>$job_id, code=>$run_sub, callback=>$cb_sub);
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

around test_scheduler => sub{
    my ($orig, $self, @args) = @_;

    subtest scheduler => sub{
        $self->$orig( @args );
    };

    return;
};

sub test_scheduler {
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

sub test_driver {
    my ($self) = @_;

    my $lift = $self->new_manager();

    ok(1, 'dummy');

    return;
}

1;
