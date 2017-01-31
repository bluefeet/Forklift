package Forklift::Job;

=head1 NAME

Forklift::Job - A task for Forklift to run.

=head1 SYNOPSIS

    my $lift = Forklift->new();
    
    my $job = $lift->new_job( %job_args );
    $lift->schedule_job( $job );

=head1 DESCRIPTION

A job in L<Forklift> is primarly a code reference which gets run
by the L<Forklift/driver>.

=cut

use Try::Tiny;
use Types::Standard -types;
use Types::Common::String -types;

use Moo;
use strictures 2;
use namespace::clean;

=head1 REQUIRED ARGUMENTS

=head2 code

A code reference to run when L</run> is called.

=cut

has code => (
    is       => 'ro',
    isa      => CodeRef,
    required => 1,
);

=head1 OPTIONAL ARGUMENTS

=head2 id

An arbitrary ID for this job.  Defaults to C<anon_job>.  Can
be set to anything you like and can be useful when in generic
callbacks or when processing results.

=cut

has id => (
    is      => 'ro',
    isa     => NonEmptySimpleStr,
    default => 'anon_job',
);

=head2 callback

A code reference to call when the job completes by L</run_callback>.

=cut

has callback => (
    is  => 'ro',
    isa => CodeRef,
);

=head1 METHODS

=head2 run

Executes the L</code> in an C<eval>.  Returns a hashref of arguments
suitable for creating a new L<Forklift::Result> object.

This method is meant to be called by Forklift drivers.

=cut

sub run {
    my ($self) = @_;

    return try {
        my ($data) = $self->code->( $self );
        return {
            success => 1,
            data    => $data,
        };
    }
    catch {
        return {
            success => 0,
            error   => $_,
        };
    };
}

=head2 run_callback

Expects a new L<Forklift::Result> object to be passed then executes
the L</callback> passing two arguments: the result object and job object.

If L</callback> is not set then this just returns without doing anything.

This method is meant to be called by Forklift drivers.

=cut

sub run_callback {
    my ($self, $result) = @_;

    my $cb = $self->callback();
    return if !$cb;

    $cb->( $result, $self );
    return;
}

1;
__END__

=head1 AUTHORS AND LICENSE

See L<Forklift/AUTHOR> and L<Forklift/LICENSE>.

