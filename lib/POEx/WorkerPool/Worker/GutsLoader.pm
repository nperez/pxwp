package POEx::WorkerPool::Worker::GutsLoader;

#ABSTRACT: A Loader implementation for Worker::Guts

use MooseX::Declare;

class POEx::WorkerPool::Worker::GutsLoader
{
    with 'POEx::WorkerPool::Role::WorkerPool::Worker::GutsLoader';
    method import (ClassName $class: ArrayRef[ClassName] :$traits?)
    {
        if(defined($traits))
        {
            POEx::WorkerPool::Worker::GutsLoader->meta->make_mutable;
            foreach my $trait (@$traits)
            {
                with $trait;
            }
            POEx::WorkerPool::Worker::GutsLoader->meta->make_immutable;
        }
    }
}

1;
__END__

=head1 DESCRIPTION

This is only a shell of a class. For details on available methods and 
attributes please see POEx::WorkerPool::Role::WorkerPool::Worker::GutsLoader

