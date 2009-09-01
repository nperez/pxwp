package POEx::WorkerPool::Role::Job;

#ABSTRACT: Provides a role for common job semantics

use MooseX::Declare;

role POEx::WorkerPool::Role::Job
{
    use TryCatch;
    use Data::UUID;
    use MooseX::AttributeHelpers;
    
    use MooseX::Types::Moose(':all');
    use MooseX::Types::Structured(':all');
    use POEx::WorkerPool::Types(':all');
    use POEx::WorkerPool::WorkerEvents(':all');
    use POEx::WorkerPool::Error::JobError;

    use aliased 'POEx::WorkerPool::Error::JobError';

=attr ID is: ro, isa: Str

This attribute stores the unique ID for the job. By default it uses 
Data::UUID::create_str()

=cut

    has ID => ( is => 'ro', isa => Str, lazy => 1, default => sub { Data::UUID->new()->create_str() } );

=attr steps metaclass: Collection::Array, is: ro, isa: ArrayRef[JobStep]

This attribute stores the steps for the job. All jobs must have one step. 

The following provides are defined to access the steps of the job:

    {
        push    => 'enqueue_step',
        shift   => 'dequeue_step',
        count   => 'count_steps',
    }

=cut

    has steps => 
    (
        metaclass => 'Collection::Array',
        is => 'ro', 
        isa => ArrayRef[JobStep],
        default => sub { [] },
        provides =>
        {
            push    => 'enqueue_step',
            shift   => 'dequeue_step',
            count   => 'count_steps',
        }
    );

    has total_steps => ( is => 'rw', isa => Int );
    
    method BUILD { 1; }
    around BUILD
    {
        $self->total_steps($self->count_steps);
    }

=method is_multi_step returns (Bool)

A simple convenience method to check if the job has multiple steps

=cut

    method is_multi_step returns (Bool)
    {
        return ($self->total_steps > 1);
    }

=method execute_step returns (JobStatus)

execute_step dequeues a step from steps and executes it, building a proper 
JobStatus return value. If there is an exception it builds throws a JobError

=cut
    method execute_step returns (JobStatus)
    {
        if($self->count_steps <= 0)
        {
            JobError->throw
            (
                {
                    job => $self, 
                    job_status => 
                    {
                        type => +PXWP_JOB_FAILED,
                        ID => $self->ID,
                        msg => \'Malformed job. No steps',
                    }
                }
            );
        }

        try
        {
            my $step = $self->dequeue_step();
            my $val = $step->[0]->(@{$step->[1]});
            if($self->count_steps > 0)
            {
                return 
                {
                    type => +PXWP_JOB_PROGRESS,
                    ID => $self->ID,
                    msg => \$val,
                    percent_complete => int((($self->total_steps - $self->count_steps) / $self->total_steps) * 100),
                };
            }
            else
            {
                return
                {
                    type => +PXWP_JOB_COMPLETE,
                    ID => $self->ID,
                    msg => \$val,
                };
            }

        }
        catch ($error)
        {
            JobError->throw
            (
                {
                    job => $self,
                    job_status =>
                    {
                        type => +PXWP_JOB_FAILED,
                        ID => $self->ID,
                        msg => \$error
                    }
                }
            );
        }
    }
}

1;
__END__
