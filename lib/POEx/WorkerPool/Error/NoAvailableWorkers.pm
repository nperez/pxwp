package POEx::WorkerPool::Error::NoAvailableWorkers;

#ABSTRACT: An error class indicating that no workers are available

use MooseX::Declare;

class POEx::WorkerPool::Error::NoAvailableWorkers extends POEx::WorkerPool::Error
{

}

1;
__END__

=head1 DESCRIPTION

This exception class is thrown when attempting to enqueue a job but there are
no workers available (either all are active, or have full job queues)

