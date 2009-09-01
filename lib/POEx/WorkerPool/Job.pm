package POEx::WorkerPool::Job;

#ABSTRACT: A generic job wrapper implementation

use MooseX::Declare;

class POEx::WorkerPool::Job
{
    with 'POEx::WorkerPool::Role::Job';
    method import (ClassName $class: ArrayRef[ClassName] :$traits?)
    {
        if(defined($traits))
        {
            POEx::WorkerPool::Job->meta->make_mutable;
            foreach my $trait (@$traits)
            {
                with $trait;
            }
            POEx::WorkerPool::Job->meta->make_immutable;
        }
    }
}

1;
__END__
