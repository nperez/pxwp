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
    
    use Data::UUID;
    use POE::Filter::Reference;
    use POE::Wheel::ReadWrite;
    
    use POEx::WorkerPool::Error::JobError;

    use POEx::WorkerPool::WorkerEvents(':all');

    use aliased 'POEx::Role::Event';
    use aliased 'POEx::WorkerPool::Error::JobError';
    
    # As of POE v1.266 Wheel::ReadWrite does not subclass from POE::Wheel. bleh
    has host => ( is => 'rw', isa => Object );

    has current_job => ( is => 'rw', isa => DoesJob );


=method after _start is Event

_start is advised to buid the communication wheel back to the parent process
and also register a signal handler for DIE so we can communicate exceptions
back to the parent

=cut

    after _start is Event
    {
        my $wheel = POE::Wheel::ReadWrite->new
        (   
            'InputHandle'   => \*STDIN,
            'OutputHandle'  => \*STDOUT,
            'Filter'        => POE::Filter::Reference->new(),
            'InputEvent'    => 'init_job',
        );

        $self->host($wheel);
        $self->poe->kernel->sig( 'DIE' => 'die_signal');
    }

=method init_job(DoesJob $job, WheelID $wheel) is Event

init_job is the InputEvent on the ReadWrite wheel that accepts input from the
parent process. It attempts to call ->init_job on the job it receives. If that
is successful it will then proceed on to send a return message of PXWP_JOB_START
and yield to process_job()

=cut

    method init_job(DoesJob $job, WheelID $wheel) is Event
    {
        my $fail;
        try
        {
            $job->init_job();
        }
        catch($err)
        {
            $self->call($self, 'send_message', { ID => $job->ID, type => +PXWP_JOB_FAILED, msg => \$err, } );
            $fail = 1;
        }
        
        return if defined($fail);
        $self->current_job($job);
        $self->yield('send_message', { ID => $job->ID, type => +PXWP_JOB_START, msg => \time() });
        $self->yield('process_job', $job);
    }

=method process_job(DoesJob $job) is Event

process_job takes the initialized job and calls ->execute_step on the job. If
there is more than one step, another process_job will be queued up via POE with
the same job as the argument. Each step along the way returns a JobStatus which
is then sent on to send_message which communicates with the parent process

=cut

    method process_job(DoesJob $job) is Event
    {
        try
        {
            my $status = $job->execute_step();
            $self->yield('send_message', $status);
        }
        catch(JobError $err)
        {
            $self->yield('send_message', $err->job_status);
        }
        catch($err)
        {
            $self->yield('send_message', { ID => $job->ID, type => +PXWP_JOB_FAILED, msg => \$err, } );
        }
        
        if($job->count_steps > 0)
        {
            $self->yield('process_job', $job);
        }
    }

=method send_message(JobStatus $status) is Event

send_messge communicates with the parent process each JobStatus it receives.

=cut

    method send_message(JobStatus $status) is Event
    {
        if(!defined($self->host))
        {
            die "Unable to communicate with the host";
        }

        $self->host()->put($status);
    }

=method die_signal(Str $signal, HashRef $stuff) is Event

die_signal is our signal handler if something unexpected happens.

=cut

    method die_signal(Str $signal, HashRef $stuff) is Event
    {
        $self->call($self, 'send_message', { ID => $self->current_job->ID, type => +PXWP_WORKER_CHILD_ERROR, msg => $stuff, });
    }
}

1;
__END__
