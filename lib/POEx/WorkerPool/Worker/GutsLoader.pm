package POEx::WorkerPool::Worker::GutsLoader;

#ABSTRACT: A Loader implementation for Worker::Guts

use MooseX::Declare;

class POEx::WorkerPool::Worker::GutsLoader
{
    with 'MooseX::CompileTime::Traits';
    with 'POEx::WorkerPool::Role::WorkerPool::Worker::GutsLoader';
}

1;
__END__

=head1 DESCRIPTION

This is only a shell of a class. For details on available methods and 
attributes please see POEx::WorkerPool::Role::WorkerPool::Worker::GutsLoader

