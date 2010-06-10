package POEx::WorkerPool::Role::WorkerPool::OpenEndedWorker;

#ABSTRACT: A role that provides common semantics for open ended Workers

use MooseX::Declare;

=head1 DESCRIPTION

The default Worker role provides a great amount of control for set runs of jobs
allowing all sorts of statistics to be captured of failed vs. completed jobs,
etc. But sometimes, all of that functionality isn't needed when a dumb worker
will fit the bill much better. That is what this role provides. It ignores the
queue limits, job worker status, and is a truly opened ended worker. It will
spin up as soon as _start is called and periodically check the queue for jobs.
It will exhaust the queue each check provided it hasn't been halted or told to
stop_processing.

=head1 SYNOPSIS

    # Put this use statement prior to any invocations of WorkerPool
    # See MooseX::CompileTime::Traits for more details
    use POEx::WorkerPool::Worker traits => ['POEx::WorkerPool::Role::WorkerPool::OpenEndedWorker'];

=cut

role POEx::WorkerPool::Role::WorkerPool::OpenEndedWorker
{
    with 'POEx::WorkerPool::Role::WorkerPool::Worker';

    use MooseX::Types;
    use MooseX::Types::Moose(':all');
    use MooseX::Types::Structured(':all');
    use POEx::Types(':all');
    use POEx::WorkerPool::Types(':all');
    use POEx::WorkerPool::WorkerEvents(':all');

    use POEx::WorkerPool::Error::StartError;
    use POEx::WorkerPool::Error::JobError;

    use aliased 'POEx::WorkerPool::Role::Job';
    use aliased 'POEx::WorkerPool::Worker::GutsLoader';
    use aliased 'POEx::WorkerPool::Error::StartError';
    use aliased 'POEx::WorkerPool::Error::JobError';
    use aliased 'POEx::Role::Event';

=attribute_public stop_processing

  is: rw, isa: Bool, default: 0

stop_processing is a flag used to stop periodic processing of the queue

=cut

    has stop_processing => (is => 'rw', isa => Bool, default => 0);


=attribute_public process_queue_interval

  is: ro, isa: Int, default: 1

process_queue_interval defines the interval for queue processing. This value is
passed directly to POEs L<POE::Kernel/delay_add> method.

=cut

    has process_queue_interval => (is => 'ro', isa => Int, default => 1);


=attribute_private _in_process_jobs

    is: ro, isa: HashRef[DoesJob], traits: Hash

This is the in process store of jobs for the open ended worker. Jobs are placed
into this structure prior to being passed to the Guts component

The following handles are provided:

    {
        _get_in_process => 'get',
        _add_in_process => 'set',
        _del_in_process => 'delete',
    }

=cut

    has _in_process_jobs =>
    (
        is => 'ro',
        isa => HashRef[DoesJob], 
        traits => ['Hash'],
        default => sub { +{ } },
        handles =>
        {
            _get_in_process => 'get',
            _add_in_process => 'set',
            _del_in_process => 'delete',
        }
    );

=method_protected after _start

 is Event

_start is advised to start the prcessing queue using the L</process_queue_interval>

=cut

    after _start is Event
    {
        $self->poe->kernel->delay_add('_process_queue', $self->process_queue_interval);
    }

=method_public enqueue_job

 (DoesJob $job)

enqueue_job is advised to bypass the queue checks to allow an open ended worker
queue.

This method fires +PXWP_JOB_ENQUEUED to the associated PubSub component on
success.

Subscribers will need to have the following signature:

    method handler (SessionID :$worker_id, DoesJob $job ) is Event

=cut

    around enqueue_job(DoesJob $job) is Event
    {
        my $kernel = defined($self->poe->kernel) ? $self->poe->kernel : 'POE::Kernel';
        
        $self->_enqueue_job($job);
        
        $kernel->post
        (
            $self->pubsub_alias, +PXWP_JOB_ENQUEUED, 
            worker_id => $self->ID,
            job => $job,
        );
    }

=method_public enqueue_jobs

 (ArrayRef[DoesJob] $jobs)

enqueue_jobs does the same thing as enqueue_job, but it acts on an array of
jobs. Each job successfully enqueued means the worker will fire the 
+PXWP_JOB_ENQUEUED event via PubSub.

=cut

    around enqueue_jobs(ArrayRef[DoesJob] $jobs) is Event
    {
        my $kernel = defined($self->poe->kernel) ? $self->poe->kernel : 'POE::Kernel';
        
        map 
        {
            $self->_enqueue_job($_); 
            $kernel->post
            (
                $self->pubsub_alias, +PXWP_JOB_ENQUEUED, 
                worker_id => $self->ID,
                job => $_,
            );
        }
        @$jobs;
    }

    around start_processing is Event
    {
        return;
    }

=method_private _process_queue

 is Event

This private event is the queue processor. As jobs are dequeued for processing,
+PXWP_JOB_DEQUEUED will be fired via PubSub. Subscribers will need the
following signature:

    method handler(SessionID :$worker_id, DoesJob :$job) is Event

Once this method is called, it will exhaust the current queue and set itself up
to be called again on an interval of one second. The interval is configurable
via the L</process_queue_interval>

=cut

    around _process_queue is Event
    {   
        while(my $job = $self->_dequeue_job())
        {
            $self->post
            (
                $self->pubsub_alias, +PXWP_JOB_DEQUEUED, 
                worker_id => $self->ID,
                job => $job,
            );
            
            $self->yield('_process_job', $job);
        }

        unless($self->stop_processing)
        {
            $self->poe->kernel->delay_add('_process_queue', $self->process_queue_interval);
        }
    }

=method_private _process_job

 (DoesJob $job) is Event

This private event is advised to store the in-process jobs into a separate data
structure (since multiple are in flight at once) before being processed. If the
child process doesn't exist for whatever reason, +PXWP_WORKER_INTERNAL_ERROR
will be fired via PubSub. Subscribers need the following signature:

    method handler(SessionID :$worker_id, Ref :$msg)

In process jobs can be accessed by ID in the L</_in_process_jobs> attribute.

=cut

    around _process_job(DoesJob $job) is Event
    {
        if(!defined($self->child_wheel))
        {
            $self->post
            (
                $self->pubsub_alias, +PXWP_WORKER_INTERNAL_ERROR, 
                worker_id => $self->ID,
                msg => \'Child process was null',
            );

            return;
        }
        
        $self->_add_in_process($job->ID, $job);
        $self->child_wheel->put($job);
    }


=method_protected guts_output

 (JobStatus $job_status) is Event

This is the StdoutEvent for the child POE::Wheel::Run. It handles all of the
child output which is in the form of JobStatus hashrefs. The following 
describes the potential events from the child and the actions taken

+PXWP_JOB_COMPLETE
    
    Action: 
        _in_process is cleared.
    
    PubSub Event:
        +PXWP_JOB_COMPLETE
    
    PubSub Signature:
        method handler(SessionID :$worker_id, DoesJob :$job, Ref :$msg)

    Notes:
        The :$msg argument will contain the output from the Job's execution
        

+PXWP_JOB_PROGRESS
    
    Action: 
        PubSub event posted.
    
    PubSub Event:
        +PXWP_JOB_PROGRESS
    
    PubSub Signature:
        method handler
        (
            SessionID :$worker_id, 
            DoesJob :$job, 
            Int :$percent_complete,
            Ref :$msg,
        )

    Notes:
        The :$msg argument will contain the output from the last step executed
        for multi-step jobs
    
    
+PXWP_JOB_FAILED
    
    Action: 
        _in_process is cleared.
    
    PubSub Event:
        +PXWP_JOB_FAILED
    
    PubSub Signature:
        method handler(SessionID :$worker_id, DoesJob :$job, Ref :$msg)

    Notes:
        The :$msg argument will contain the exception generated from the Job
    

+PXWP_JOB_START
    
    Action: 
        PubSub event posted.
    
    PubSub Event:
        +PXWP_JOB_START
    
    PubSub Signature:
        method handler
        (
            SessionID :$worker_id, 
            DoesJob :$job, 
        )

    Notes:
        This is an indication that the child process received the Job and is
        beginning execution.
    

=cut

    around guts_output(JobStatus $job_status, WheelID $id) is Event
    {
        if($job_status->{type} eq +PXWP_JOB_COMPLETE)
        {
            $self->post
            (
                $self->pubsub_alias, +PXWP_JOB_COMPLETE,
                worker_id => $self->ID,
                job => $self->_get_in_process($job_status->{ID}),
                msg => $job_status->{msg},
            );
            
            $self->_del_in_process($job_status->{ID});
        }
        elsif($job_status->{type} eq +PXWP_JOB_PROGRESS)
        {
            $self->post
            (
                $self->pubsub_alias, +PXWP_JOB_PROGRESS,
                worker_id => $self->ID,
                job => $self->_get_in_process($job_status->{ID}),
                percent_complete => $job_status->{percent_complete},
                msg => $job_status->{msg},
            );
        }
        elsif($job_status->{type} eq +PXWP_JOB_FAILED)
        {
            $self->post
            (
                $self->pubsub_alias, +PXWP_JOB_FAILED,
                worker_id => $self->ID,
                job => $self->_get_in_process($job_status->{ID}),
                msg => $job_status->{msg},
            );
            
            $self->_del_in_process($job_status->{ID});
        }
        elsif($job_status->{type} eq +PXWP_JOB_START)
        {
            $DB::single = 1;
            $self->post
            (
                $self->pubsub_alias, +PXWP_JOB_START, 
                worker_id => $self->ID,
                job => $self->_get_in_process($job_status->{ID}),
            );
        }
        elsif($job_status->{type} eq +PXWP_WORKER_INTERNAL_ERROR)
        {
            $self->post
            (
                $self->pubsub_alias, +PXWP_WORKER_INTERNAL_ERROR,
                worker_id => $self->ID,
                msg => $job_status->{msg},
            );

            $self->halt();
        }
        else
        {
            JobError->throw({message => 'Unknown job status', job => $self->_in_process, job_status => $job_status});
        }
    }

=method_public halt

 is Event

halt is advised to stop periodic processing

=cut

    around halt is Event
    {
        my $kernel = defined($self->poe->kernel) ? $self->poe->kernel : 'POE::Kernel';
        $self->stop_processing(1);
        $kernel->alarm_remove_all();
        $self->$orig();
    }
}
1;

__END__
