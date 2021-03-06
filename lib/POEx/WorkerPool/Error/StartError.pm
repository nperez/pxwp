package POEx::WorkerPool::Error::StartError;

#ABSTRACT: An error class indicating the Worker queue failed to start

use MooseX::Declare;

class POEx::WorkerPool::Error::StartError extends POEx::WorkerPool::Error
{

}

1;
__END__

This exception is thrown when a Worker is told to start processing its queue
but there are no items within the queue
