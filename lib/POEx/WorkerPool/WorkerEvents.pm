package POEx::WorkerPool::WorkerEvents;

#ABSTRACT: Exported event symbols for WorkerPool

use warnings;
use strict;

use Moose;

use constant
{
    PXWP_WORKER_CHILD_ERROR     => 'PXWP_WORKER_CHILD_ERROR',
    PXWP_WORKER_CHILD_EXIT      => 'PXWP_WORKER_CHILD_EXIT',
    PXWP_JOB_ENQUEUED           => 'PXWP_JOB_ENQUEUED',
    PXWP_START_PROCESSING       => 'PXWP_START_PROCESSING',
    PXWP_JOB_DEQUEUED           => 'PXWP_JOB_DEQUEUED',
    PXWP_STOP_PROCESSING        => 'PXWP_STOP_PROCESSING',
    PXWP_WORKER_INTERNAL_ERROR  => 'PXWP_WORKER_INTERNAL_ERROR',
    PXWP_JOB_COMPLETE           => 'PXWP_JOB_COMPLETE',
    PXWP_JOB_PROGRESS           => 'PXWP_JOB_PROGRESS',
    PXWP_JOB_FAILED             => 'PXWP_JOB_FAILED',
    PXWP_JOB_START              => 'PXWP_JOB_START',
};

use Sub::Exporter -setup => 
{ 
    exports => 
    [ 
        qw/ 
            PXWP_WORKER_CHILD_ERROR
            PXWP_WORKER_CHILD_EXIT
            PXWP_JOB_ENQUEUED
            PXWP_START_PROCESSING
            PXWP_JOB_DEQUEUED
            PXWP_STOP_PROCESSING
            PXWP_WORKER_INTERNAL_ERROR
            PXWP_JOB_COMPLETE
            PXWP_JOB_PROGRESS
            PXWP_JOB_FAILED
            PXWP_JOB_START
        /
    ] 
};


1;
__END__

=head1 DESCRIPTION

This modules exports the needed symbols for subscribing to a Workers associated
PubSub events. See POEx::WorkerPool::Role::WorkerPool::Worker for more details
on signatures required for each event

=head1 EXPORTS

    PXWP_WORKER_CHILD_ERROR
    PXWP_WORKER_CHILD_EXIT
    PXWP_JOB_ENQUEUED
    PXWP_START_PROCESSING
    PXWP_JOB_DEQUEUED
    PXWP_STOP_PROCESSING
    PXWP_WORKER_INTERNAL_ERROR
    PXWP_JOB_COMPLETE
    PXWP_JOB_PROGRESS
    PXWP_JOB_FAILED
    PXWP_JOB_START
    PXWP_JOB_COMPLETE

=cut

