package Forklift::Results;

use Moo;
use strictures 2;
use namespace::clean;

has result_class => (
    is       => 'ro',
    required => 1,
);

has all => (
    is       => 'rwp',
    init_arg => undef,
    default  => sub{ [] },
);

sub clear {
    my ($self) = @_;
    $self->_set_all( [] );
    return;
}

sub ok {
    my ($self) = @_;

    return [
        grep { $_->success() }
        @{ $self->all() }
    ];
}

sub failed {
    my ($self) = @_;

    return [
        grep { !$_->success() }
        @{ $self->all() }
    ];
}

sub add {
    my ($self, $result) = @_;
    push @{ $self->all() }, $result;
}

sub new_result {
    my $self = shift;
    return $self->result_class->new( @_ );
}

sub add_new_result {
    my $self = shift;
    my $result = $self->new_result( @_ );
    $self->add( $result );
    return $result;
}

1;
