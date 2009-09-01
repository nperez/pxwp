package POEx::WorkerPool;

#ABSTRACT: A generic multiprocess worker pool for the POE framework

use MooseX::Declare;

class POEx::WorkerPool
{
    with 'POEx::WorkerPool::Role::WorkerPool';
    method import (ClassName $class: ArrayRef[ClassName] :$traits?)
    {
        if(defined($traits))
        {
            POEx::WorkerPool->meta->make_mutable;
            foreach my $trait (@$traits)
            {
                with $trait;
            }
            POEx::WorkerPool->meta->make_immutable;
        }
    }
}

1;
__END__
