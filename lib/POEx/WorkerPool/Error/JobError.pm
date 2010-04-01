package POEx::WorkerPool::Error::JobError;

#ABSTRACT: An error class indicating something failed with the job

use MooseX::Declare;

class POEx::WorkerPool::Error::JobError extends POEx::WorkerPool::Error
{
    use POEx::WorkerPool::Types(':all');

=attribute_public job 

 is: ro, isa: DoesJob

This contains the job that errored

=cut

    has job => ( is => 'ro', isa => DoesJob, required => 1 ); 
    
=attribute_public job_status 

 is:ro, isa: JobStatus

This contains the useful information captured from the try block around the job
during execution of the previous step

=cut
    
    has job_status => ( is => 'ro', isa => JobStatus, required => 1 ); 
}

1;
__END__

=head1 DESCRIPTION

This exception is thrown when there is an irrecoverable error with a job

