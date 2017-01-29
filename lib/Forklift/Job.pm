package Forklift::Job;

use Try::Tiny;
use Types::Standard -types;
use Types::Common::String -types;

use Moo;
use strictures 2;
use namespace::clean;

around BUILDARGS => sub{
    my $orig = shift;
    my $self = shift;

    my $args = {};
    if (ref($_[0]) eq 'CODE') {
        $args->{code} = shift;
    }
    if (ref($_[0]) eq 'CODE') {
        $args->{callback} = shift;
    }

    return {
        %$args,
        %{ $self->$orig( @_ ) },
    };
};

has id => (
    is      => 'ro',
    isa     => NonEmptySimpleStr,
    default => 'anon_job',
);

has caller => (
    is       => 'ro',
    init_arg => undef,
    default  => \&_build_caller,
);
sub _build_caller {

}

has code => (
    is       => 'ro',
    isa      => CodeRef,
    required => 1,
);

has callback => (
    is  => 'ro',
    isa => CodeRef,
);

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

sub run_callback {
    my ($self, $result) = @_;

    my $cb = $self->callback();
    return if !$cb;

    $cb->( $result );
    return;
}

1;
