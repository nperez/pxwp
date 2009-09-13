BEGIN
{
    sub POE::Kernel::CATCH_EXCEPTIONS () { 1 }
#    sub POE::Kernel::TRACE_EVENTS () { 1 }
#    sub POE::Kernel::TRACE_FILENAME () { 'test_trace' }
}
use Test::More;
use MooseX::Declare;
use POE;

my $steps = 5;
my $good = 5;
my $bad = 2;
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
    use FailJob steps => 5;

    use Test::More;
    
    use POEx::Types(':all');
    use POEx::WorkerPool::Types(':all');
    use POEx::WorkerPool::WorkerEvents(':all');
    use MooseX::Types::Moose(':all');

    use POEx::WorkerPool;

    use aliased 'POEx::WorkerPool::Error::EnqueueError';
    
    has found_error => ( is => 'rw', isa => ScalarRef, default => sub { my $i = 1; \$i; } );

    has pool => ( is => 'ro', isa => DoesWorkerPool, lazy_build => 1 );
    method _build_pool
    {
        POEx::WorkerPool->new
        (
            max_workers => $good + $bad, 
            job_classes => ['MyJob', 'FailJob'], 
            max_jobs_per_worker => 1 
        ); 
    }

    after _start is Event
    {
        for(1..$good)
        {
            $self->subscribe_to_worker($self->pool->enqueue_job(MyJob->new()));
        }

        for(1..$bad)
        {
            $self->subscribe_to_worker($self->pool->enqueue_job(FailJob->new()));
        }
        
        my $worker = $self->pool->workers->[0];
        my ($alias, $pubsub) = ($worker->alias, $worker->pubsub_alias);

        $self->call($pubsub, 'subscribe', event_name => +PXWP_WORKER_ERROR, event_handler => 'error_handler');
        $self->post($alias, 'enqueue_job', MyJob->new());
        
    }

    method error_handler(SessionID :$worker_id, IsaError :$exception, HashRef :$original) is Event
    {
        ok($exception->isa(EnqueueError), 'We successfully got the enqueue error exception');
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

    method job_failed (SessionID :$worker_id, DoesJob :$job, Ref :$msg) is Event
    {
        if(${$self->found_error} > $bad)
        {
            fail("Found more than $bad error(s)");
            $self->pool()->halt();
            BAIL_OUT('FAILURE STATE');
        }

        diag("Job(${\$job->ID}) failed with: $$msg");
        isa_ok($job, 'FailJob', 'Got the right job');
        ${$self->found_error}++;
    }

    method worker_stop_processing (SessionID :$worker_id, Int :$completed_jobs, Int :$failed_jobs) is Event
    {
        $worker_stops++;
        pass("Worker($worker_id) has finished processing its jobs. Complete: $completed_jobs, Failed: $failed_jobs\n");
        diag("Worker($worker_id) has finished processing its jobs. Complete: $completed_jobs, Failed: $failed_jobs\n");

        my $alias = $self->poe->kernel->ID_id_to_session($worker_id)->pubsub_alias;
        $self->unsubscribe_to_worker($alias);
        
        if($worker_stops == ($good + $bad))
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
    
    method job_dequeued (SessionID :$worker_id, DoesJob :$job) is Event
    {
        $dequeues++;
        pass("Worker($worker_id) dequeued Job(${\$job->ID})\n");
        diag("Worker($worker_id) dequeued Job(${\$job->ID})\n");
    }
    
    method job_enqueued (SessionID :$worker_id, DoesJob :$job) is Event
    {
        $enqueues++;
        pass("Worker($worker_id) queued Job(${\$job->ID})\n");
        diag("Worker($worker_id) queued Job(${\$job->ID})\n");
    }

    method job_start (SessionID :$worker_id, DoesJob :$job) is Event
    {
        $starts++;
        pass("Worker($worker_id) has started Job(${\$job->ID})\n");
        diag("Worker($worker_id) has started Job(${\$job->ID})\n");
    }

    
    method job_complete (SessionID :$worker_id, DoesJob :$job, Ref :$msg) is Event
    {
        $completes++;
        pass("Worker($worker_id) finished Job(${\$job->ID})\n");
        diag("Worker($worker_id) finished Job(${\$job->ID})\n");
    }

    method job_progress (SessionID :$worker_id, DoesJob :$job, Int :$percent_complete, Ref :$msg) is Event
    {
        $progresses++;
        pass("Worker($worker_id) is %$percent_complete with Job(${\$job->ID})");
        diag("Worker($worker_id) is %$percent_complete with Job(${\$job->ID})");
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
        $self->call($alias, 'subscribe', event_name => +PXWP_JOB_FAILED, event_handler => 'job_failed');
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

is($starts, $good + $bad , 'Right number of starts');
is($completes, $good, 'Right number of completes');
is($progresses, ($good * ($steps - 1)) + $bad, 'Right number of progresses');
is($enqueues, $good + $bad, 'Right number of enqueues');
is($dequeues, $good + $bad, 'Right number of dequeues');
is($worker_starts, $good + $bad, 'Right number of worker starts');
is($worker_stops, $good + $bad, 'Right number of worker stops');

done_testing();
