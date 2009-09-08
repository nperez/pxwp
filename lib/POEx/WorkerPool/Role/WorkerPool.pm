package POEx::WorkerPool::Role::WorkerPool;

#ABSTRACT: A role that provides common semantics for WorkerPools

use MooseX::Declare;

role POEx::WorkerPool::Role::WorkerPool
{
    use Moose::Util::TypeConstraints;
    use MooseX::Types::Moose(':all');
    use POEx::WorkerPool::Types(':all');
    use POEx::Types(':all');
    
    use POEx::WorkerPool::Worker;
    use POEx::WorkerPool::Error::NoAvailableWorkers;

    use aliased 'POEx::WorkerPool::Worker';
    use aliased 'POEx::WorkerPool::Error::NoAvailableWorkers';

=attr job_class is: ro, isa: ClassName, required: 1

In order for the serializer on the other side of the process boundary to
rebless jobs on the other side, it needs to make sure that class is loaded.

This attribute is used to indicate which class needs to be loaded.

=cut

    has job_class => ( is => 'ro', isa => ClassName, required => 1);

=attr queue_type is: ro, isa: enum([qw|round_robin fill_up|]), default: round_robin

This attribute specifies the queue type for the WorkerPool and changes how
workers are pulled from the pool

=cut
    has queue_type => ( is => 'ro', isa => enum([qw|round_robin fill_up|]), default => 'round_robin');
    
=attr max_workers is: ro, isa: Int, default: 5

This determines how many workers the Pool will spin up

=cut
    
    has max_workers => ( is => 'ro', isa => Int, default => 5 );
    
=attr current_worker_index is: rw, isa: ScalarRef

This stores the current index into workers. Dereference to manipulate the Int value.

=cut

    has current_worker_index => ( is => 'rw', isa => ScalarRef, lazy_build => 1);
    method _build_current_worker_index { my $i = 0; \$i };


=attr workers is: ro, isa: ArrayRef[Worker]

This attribute holds all of the workers in the pool

=cut

    has workers => 
    (
        is => 'ro',
        isa => ArrayRef[DoesWorker],
        lazy_build => 1,
    );
    method _build_workers
    {
        my $workers = [];

        for(0..$self->max_workers)
        {
            push( @$workers, Worker->new( job_class => $self->job_class ) );
        }

        return $workers;
    }

    method BUILDARGS (ClassName $class: @args)
    {
        my %retargs = @args;
        Class::MOP::load_class($retargs{job_class});
        return \%retargs;
    }

=method incr_worker_index returns Int

This is a convenience method for incrementing the index and wrapping around
when it exceeds max_workers

=cut

    method incr_worker_index returns (Int)
    {
        if(++${$self->current_worker_index} > $self->max_workers - 1)
        {
            $self->clear_current_worker_index();
        }
        
        return ${$self->current_worker_index};
    }

=method get_next_worker returns (DoesWorker)

This returns the next worker in the pool as determined by the queue_type
attribute.

For round_robin, it will return the next immediate worker if isn't active.
fill_up will continue to return the same worker until its job queue is full.

If it is unable to return a suitable worker (all of the workers are currently
active or all of their job queues are full, etc), it will throw a
POEx::WorkerPool::Error::NoAvailableWorkers exception.

=cut

    method get_next_worker(Int $index?) returns (DoesWorker)
    {
        NoAvailableWorkers->throw({message => 'Iterated through all workers and none are available'}) 
            if defined($index) && $index == ${$self->current_worker_index};
        
        if($self->queue_type eq 'round_robin')
        {
            my $worker = $self->workers()->[$self->incr_worker_index];
            
            if($worker->is_active)
            {
                return $self->get_next_worker( defined($index) ? $index : ${$self->current_worker_index} );
            }
            else
            {
                return $worker;
            }
        }
        elsif($self->queue_type eq 'fill_up')
        {
            my $current = $self->workers()->[${$self->current_worker_index}];
            
            if($current->count_jobs < $current->max_jobs && $current->is_not_active)
            {
                return $current;
            }
            else
            {
                return $self->get_next_worker( defined($index) ? $index : $self->incr_worker_index );
            }
        }
    }

=method queue_job(DoesJob $job) returns (SessionAlias)

This method grabs the next available worker, enqueues the job, starts the
worker's queue processing and returns the worker's pubsub alias that can be 
used to subscribe to various events that the worker fires.

=cut

    method enqueue_job(DoesJob $job) returns (SessionAlias)
    {
        my $worker = $self->get_next_worker();
        $worker->enqueue_job($job);
        $worker->start_processing();
        return $worker->pubsub_alias;
    }

=method halt is Event

This method will halt any active workers in the worker pool and force them to
release resouces and clean up.

=cut

    method halt 
    {
        $_->halt() for (@{$self->workers});
    }
}

1;
__END__
