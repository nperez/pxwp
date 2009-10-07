package POEx::WorkerPool::Worker;

#ABSTRACT: A generic worker class for WorkerPool

use MooseX::Declare;

class POEx::WorkerPool::Worker
{
    with 'MooseX::CompileTime::Traits';
    with 'POEx::WorkerPool::Role::WorkerPool::Worker';
}

1;
__END__

=head1 DESCRIPTION

This is only a shell of a class. For details on available methodsand attributes
please see POEx::WorkerPool::Role::WorkerPool::Worker

