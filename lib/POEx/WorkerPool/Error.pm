package POEx::WorkerPool::Error;

use MooseX::Declare;

#ABSTRACT: Error class for WorkerPool using Throwable

class POEx::WorkerPool::Error with Throwable
{
    use MooseX::Types::Moose(':all');

=attr message is: ro, isa: Str, required: 1

A human readable error message

=cut
    has message => ( is => 'ro', isa => Str, required => 1);
}

1;

__END__
