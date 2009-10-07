package POEx::WorkerPool::Worker::Guts;

#ABSTRACT: A generic sub process implementation for Worker

use MooseX::Declare;

class POEx::WorkerPool::Worker::Guts
{
    with 'MooseX::CompileTime::Traits';
    with 'POEx::WorkerPool::Role::WorkerPool::Worker::Guts';
}

1;
__END__

=head1 DESCRIPTION

This is only a shell of a class. For details on available methods and 
attributes please see POEx::WorkerPool::Role::WorkerPool::Worker::Guts

