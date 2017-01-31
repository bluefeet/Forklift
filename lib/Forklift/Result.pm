package Forklift::Result;

=head1 NAME

Forklift::Result - The results of running a single job.

=head1 DESCRIPTION

In Forklift, when a job completes, the driver creates an instance of
this class and passes it to the callback (if one was set) in the
L<Forklift::Job> object.  The callback can then take action on the
finished job as necessary.

=cut

use Types::Standard -types;
use Types::Common::String -types;

use Moo;
use strictures 2;
use namespace::clean;

=head1 REQUIRED ARGUMENTS

=head2 job_id

The ID of the job, as copied from L<Forklift::Job/id>.  This is provided
so that the user of Forklift can correlated a result object with a job
object as necessary.

=cut

has job_id => (
    is       => 'ro',
    isa      => NonEmptySimpleStr,
    required => 1,
);

=head2 success

Whether or not the job ran successfully.

=cut

has success => (
    is       => 'ro',
    isa      => Bool,
    required => 1,
);

=head1 OPTIONAL ARGUMENTS

=head2 data

Any data returned by the job's L<Forklift::Job/code>.  The should only be set if
L</success> was set to true.

=cut

has data => (
    is => 'ro',
);

=head2 error

The error message related produced when the job failed.  This should only be set
if L</success> was set to false.

=cut

has error => (
    is => 'ro',
);

=head1 METHODS

=head2 throw

Calls C<die()> on the L</status_message> if L</success> is false.

=cut

sub throw {
    my ($self) = @_;
    return if $self->success();
    die $self->status_message();
}

=head2 status_message

Returns a string describing the results of the finished job.
Something like:

    The JOB_ID job finished successfully.

or:

    The JOB_ID job failed: ERROR

=cut

sub status_message {
    my ($self) = @_;

    return sprintf(
        'The %s job %s',
        $self->job_id(),
        $self->success()
            ? 'finished successfully.'
            : 'failed: ' . $self->error(),
    );
}

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

