package POEx::WorkerPool::Worker;

#ABSTRACT: A generic worker class for WorkerPool

use MooseX::Declare;

class POEx::WorkerPool::Worker
{
    with 'POEx::WorkerPool::Role::WorkerPool::Worker';
    method import (ClassName $class: ArrayRef[ClassName] :$traits?)
    {
        if(defined($traits))
        {
            POEx::WorkerPool::Worker->meta->make_mutable;
            foreach my $trait (@$traits)
            {
                with $trait;
            }
            POEx::WorkerPool::Worker->meta->make_immutable;
        }
    }
}

1;
__END__

=head1 DESCRIPTION

This is only a shell of a class. For details on available methodsand attributes
please see POEx::WorkerPool::Role::WorkerPool::Worker

