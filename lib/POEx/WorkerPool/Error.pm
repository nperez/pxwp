package POEx::WorkerPool::Error;

use MooseX::Declare;

#ABSTRACT: Error class for WorkerPool using Throwable

class POEx::WorkerPool::Error with Throwable
{
    use MooseX::Types::Moose(':all');

=attribute_public message is: ro, isa: Str, required: 1

A human readable error message

=cut

    has message => ( is => 'ro', isa => Str, required => 1);
}

1;

__END__

=head1 DESCRIPTION

This is mostly a base class for other exeptions within POEx::WorkerPool.

Please see any of the following for more information:

    POEx::WorkerPool::Error::EnqueueError
    POEx::WorkerPool::Error::JobError
    POEx::WorkerPool::Error::NoAvailableWorkers
    POEx::WorkerPool::Error::StartError

