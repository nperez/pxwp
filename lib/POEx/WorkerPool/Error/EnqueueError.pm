package POEx::WorkerPool::Error::EnqueueError;

#ABSTRACT: An error class indicating problems enqueuing a job

use MooseX::Declare;

class POEx::WorkerPool::Error::EnqueueError extends POEx::WorkerPool::Error
{

}

1;
__END__

=head1 DESCRIPTION

This exception is thrown when there are issues enqueuing a job for execution.
