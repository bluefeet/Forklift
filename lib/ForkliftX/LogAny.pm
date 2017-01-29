package ForkliftX::LogAny;

use Log::Any qw( $log );

use Moo::Role;
use strictures 2;
use namespace::clean;

use MooX::PluginKit::Plugin;

plugin_applies_to 'Forklift::Job';

around run => sub{
    my $orig = shift;
    my $self = shift;

    $log->infof(
        'Running the %s job.',
        $self->id(),
    );

    my $result = $self->$orig( @_ );

    my $log_method = $result->{succcess} ? 'infof' : 'errorf';
    $log->$log_method(
        'The %s job has %s',
        $self->id(),
        $result->{success}
            ? 'finished.'
            : 'FAILED: ' . $result->{error},
    );

    return $result;
};

around run_callback => sub{
    my $orig = shift;
    my $self = shift;

    $log->infof(
        'Running callback for the %s job.',
        $self->id(),
    );

    $self->$orig( @_ );

    $log->infof(
        'The callback for the %s job has finished.',
        $self->id(),
    );

    return;
};

1;
