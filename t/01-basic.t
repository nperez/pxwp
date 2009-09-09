BEGIN
{
    sub POE::Kernel::CATCH_EXCEPTIONS () { 0 }
}
use Test::More;
use MooseX::Declare;
use POE;

my $steps = 5;
my $jobs = 5;
my $starts = 0;
my $completes = 0;
my $progresses = 0;
my $worker_starts = 0;
my $worker_stops = 0;
my $enqueues = 0;
my $dequeues = 0;

class MyTester
{
    with 'POEx::Role::SessionInstantiation';
    use aliased 'POEx::Role::Event';
    
    use FindBin;
    use lib "$FindBin::Bin/lib";
    
    use MyJob steps => 5;

    use Test::More;
    
    use POEx::Types(':all');
    use POEx::WorkerPool::Types(':all');
    use POEx::WorkerPool::WorkerEvents(':all');

    use POEx::WorkerPool;
    
    has pool => ( is => 'ro', isa => DoesWorkerPool, lazy_build => 1 );
    method _build_pool { POEx::WorkerPool->new( job_class => 'MyJob', max_jobs_per_worker => 1 ) }

    after _start is Event
    {
        for(1..$jobs)
        {
            my $alias = $self->pool->enqueue_job(MyJob->new());
            $self->subscribe_to_worker($alias);
        }
    }

    method bailout_worker_child_err
    (
        SessionID :$worker_id,
        Str :$operation,
        Int :$error_number,
        Str :$error_string,
        WheelID :$wheel_id,
        Str :$handle_name
    ) is Event
    {
        fail
        (
            'PXWP_WORKER_CHILD_ERROR: ' . 
            "Worker($worker_id) failed in op($operation), with err($error_number)/msg($error_string) involving handle($handle_name)"
        );
        $self->pool()->halt();
        BAIL_OUT('FAILURE STATE');
    }
    method bailout_worker_child_exit(SessionID :$worker_id, Int :$process_id, Int :$exit_value) is Event
    {
        fail('PXWP_WORKER_CHILD_EXIT: ' . "Worker($worker_id)'s process($process_id) has exited with exit_value($exit_value)");
        $self->pool()->halt();
        BAIL_OUT('FAILURE STATE');
    }
    method bailout_worker_internal is Event
    {
        fail('PXWP_WORKER_INTERNAL_ERROR');
        $self->pool()->halt();
        BAIL_OUT('FAILURE STATE');
    }
    method bailout_job_failed is Event
    {
        fail('PXWP_JOB_FAILED');
        $self->pool()->halt();
        BAIL_OUT('FAILURE STATE');
    }

    method worker_stop_processing (SessionID :$worker_id, Int :$completed_jobs, Int :$failed_jobs) is Event
    {
        $worker_stops++;
        is($failed_jobs, 0, 'Completed all jobs without failures');
        pass("Worker($worker_id) has finished processing its jobs. Complete: $completed_jobs, Failed: $failed_jobs\n");
        diag("Worker($worker_id) has finished processing its jobs. Complete: $completed_jobs, Failed: $failed_jobs\n");

        my $alias = $self->poe->kernel->ID_id_to_session($worker_id)->pubsub_alias;
        $self->unsubscribe_to_worker($alias);
        
        if($worker_stops == $jobs)
        {
            $self->pool->halt();
        }
    }

    method worker_start_processing (SessionID :$worker_id, Int :$count_jobs) is Event
    {
        $worker_starts++;
        pass("Worker($worker_id) has started processing its $count_jobs jobs\n");
        diag("Worker($worker_id) has started processing its $count_jobs jobs\n");
    }
    
    method job_dequeued (SessionID :$worker_id, Str :$job_id) is Event
    {
        $dequeues++;
        pass("Worker($worker_id) dequeued Job($job_id)\n");
        diag("Worker($worker_id) dequeued Job($job_id)\n");
    }
    
    method job_enqueued (SessionID :$worker_id, Str :$job_id) is Event
    {
        $enqueues++;
        pass("Worker($worker_id) queued Job($job_id)\n");
        diag("Worker($worker_id) queued Job($job_id)\n");
    }

    method job_start (SessionID :$worker_id, Str :$job_id) is Event
    {
        $starts++;
        pass("Worker($worker_id) has started Job($job_id)\n");
        diag("Worker($worker_id) has started Job($job_id)\n");
    }

    
    method job_complete (SessionID :$worker_id, Str :$job_id, Ref :$msg) is Event
    {
        $completes++;
        pass("Worker($worker_id) finished Job($job_id)\n");
        diag("Worker($worker_id) finished Job($job_id)\n");
    }

    method job_progress (SessionID :$worker_id, Str :$job_id, Int :$percent_complete, Ref :$msg) is Event
    {
        $progresses++;
        pass("Worker($worker_id) is %$percent_complete with Job($job_id)");
        diag("Worker($worker_id) is %$percent_complete with Job($job_id)");
    }

    method subscribe_to_worker(SessionRefIdAliasInstantiation $alias)
    {
        $self->call($alias, 'subscribe', event_name => +PXWP_WORKER_CHILD_ERROR, event_handler => 'bailout_worker_child_err');
        $self->call($alias, 'subscribe', event_name => +PXWP_WORKER_CHILD_EXIT, event_handler => 'bailout_worker_child_exit');
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_ENQUEUED, event_handler => 'job_enqueued');
        $self->call($alias, 'subscribe', event_name => +PXWP_START_PROCESSING, event_handler => 'worker_start_processing');
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_DEQUEUED, event_handler => 'job_dequeued');
        $self->call($alias, 'subscribe', event_name => +PXWP_STOP_PROCESSING, event_handler => 'worker_stop_processing');
        $self->call($alias, 'subscribe', event_name => +PXWP_WORKER_INTERNAL_ERROR, event_handler => 'bailout_worker_internal');
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_COMPLETE, event_handler => 'job_complete');
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_PROGRESS, event_handler => 'job_progress');
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_FAILED, event_handler => 'bailout_job_failed');
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_START, event_handler => 'job_start');
    }
    
    method unsubscribe_to_worker(SessionRefIdAliasInstantiation $alias)
    {
        $self->call($alias, 'cancel', event_name => +PXWP_WORKER_CHILD_ERROR);
        $self->call($alias, 'cancel', event_name => +PXWP_WORKER_CHILD_EXIT);
        $self->call($alias, 'cancel', event_name => +PXWP_JOB_ENQUEUED);
        $self->call($alias, 'cancel', event_name => +PXWP_START_PROCESSING);
        $self->call($alias, 'cancel', event_name => +PXWP_JOB_DEQUEUED);
        $self->call($alias, 'cancel', event_name => +PXWP_STOP_PROCESSING);
        $self->call($alias, 'cancel', event_name => +PXWP_WORKER_INTERNAL_ERROR);
        $self->call($alias, 'cancel', event_name => +PXWP_JOB_COMPLETE);
        $self->call($alias, 'cancel', event_name => +PXWP_JOB_PROGRESS);
        $self->call($alias, 'cancel', event_name => +PXWP_JOB_FAILED);
        $self->call($alias, 'cancel', event_name => +PXWP_JOB_START);
    }
}

my $tester = MyTester->new();
POE::Kernel->run();

is($starts, $jobs , 'Right number of starts');
is($completes, $jobs, 'Right number of completes');
is($progresses, $jobs * ($steps - 1), 'Right number of progresses');
is($enqueues, $jobs, 'Right number of enqueues');
is($dequeues, $jobs, 'Right number of dequeues');
is($worker_starts, $jobs, 'Right number of worker starts');
is($worker_stops, $jobs, 'Right number of worker stops');

done_testing();
