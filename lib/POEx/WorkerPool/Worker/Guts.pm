package POEx::WorkerPool::Worker::Guts;

#ABSTRACT: A generic sub process implementation for Worker

use MooseX::Declare;

class POEx::WorkerPool::Worker::Guts
{
    with 'POEx::WorkerPool::Role::WorkerPool::Worker::Guts';
    method import (ClassName $class: ArrayRef[ClassName] :$traits?)
    {
        if(defined($traits))
        {
            POEx::WorkerPool::Worker::Guts->meta->make_mutable;
            foreach my $trait (@$traits)
            {
                with $trait;
            }
            POEx::WorkerPool::Worker::Guts->meta->make_immutable;
        }
    }
}

1;
__END__

=head1 DESCRIPTION

This is only a shell of a class. For details on available methods and 
attributes please see POEx::WorkerPool::Role::WorkerPool::Worker::Guts

