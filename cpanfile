requires 'strictures'       => 2.000000;
requires 'namespace::clean' => 0.24;
requires 'Moo'              => 2.000000;
requires 'Type::Tiny'       => 1.000005;
requires 'Scalar::Util'     => 0;
requires 'MooX::PluginKit'  => 0.03;
requires 'Try::Tiny'        => 0;

recommends 'Forklift::Driver::Parallel::ForkManager' => 0;

on test => sub {
   requires 'Test2::Bundle::Extended' => '0.000051';
   suggests 'Test::LeakTrace' => 0.11;
   suggests 'Data::Dumper' => 0;
};
