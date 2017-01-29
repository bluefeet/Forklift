package Forklift::Result;

use Types::Standard -types;
use Types::Common::String -types;

use Moo;
use strictures 2;
use namespace::clean;

sub _received_in_parent_hook { }

has job_id => (
    is       => 'ro',
    isa      => NonEmptySimpleStr,
    required => 1,
);

has success => (
    is       => 'ro',
    isa      => Bool,
    required => 1,
);

has data => (
    is => 'ro',
);

has error => (
    is => 'ro',
);

sub throw {
    my ($self) = @_;
    return if $self->success();
    die $self->status_message();
}

sub status_message {
    my ($self) = @_;

    my $job = $self->job();

    return sprintf(
        'Job %s %s',
        $job->id(),
        $self->success()
            ? 'SUCCEEDED'
            : 'FAILED: ' . $self->error(),
    );
}

1;
