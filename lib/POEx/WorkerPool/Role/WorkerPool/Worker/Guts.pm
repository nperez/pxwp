package POEx::WorkerPool::Role::WorkerPool::Worker::Guts;

#ABSTRACT: A role that provides common semantics for Worker guts

use MooseX::Declare;

role POEx::WorkerPool::Role::WorkerPool::Worker::Guts
{
    with 'POEx::Role::SessionInstantiation';
    
    use TryCatch;
    
    use POEx::Types(':all');
    use POEx::WorkerPool::Types(':all');
    use MooseX::Types::Moose(':all');
    
    use POEx::WorkerPool::Error::JobError;

    use aliased 'POEx::Role::Event';
    use aliased 'POEx::WorkerPool::Error::JobError';

    has host => ( is => 'rw', isa => Wheel );

    after _start is Event
    {   
        my $wheel = POE::Wheel::ReadWrite->new
        (   
            'InputHandle'   => \*STDIN,
            'OutputHandle'  => \*STDOUT,
            'Filter'        => POE::Filter::Reference->new(),
            'InputEvent'    => 'process_job',
        );

        $self->host($wheel);
    }

    method process_job(DoesJob $job) is Event
    {
        try
        {
            $self->yield('send_message', $job->execute_step());
            $self->yield('process_job', $job) if $job->is_multi_step;
        }
        catch(JobError $error)
        {
            $self->yield('send_message', $error->job_status);
        }
    }

    method send_message(JobStatus $status) is Event
    {
        if(!defined($self->host))
        {
            die "Unable to communicate with the host";
        }

        $self->host()->put($status);
    }
}

1;
__END__
