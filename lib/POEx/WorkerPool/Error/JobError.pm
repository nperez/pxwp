package POEx::WorkerPool::Error::JobError;

#ABSTRACT: An error class indicating something failed with the job

use MooseX::Declare;

class POEx::WorkerPool::Error::JobError extends POEx::WorkerPool::Error
{
    use POEx::WorkerPool::Types(':all');
    has job => ( is => 'ro', isa => DoesJob, required => 1 ); 
    has job_status => ( is => 'ro', isa => JobStatus, required => 1 ); 
}

1;
__END__
