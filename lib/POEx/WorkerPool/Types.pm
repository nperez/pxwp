package POEx::WorkerPool::Types;

use warnings;
use strict;

#ABSTRACT: Type constraints for POEx::WorkerPool

=head1 DESCRIPTION

This module exports the type constrains needed for POEx::WorkerPool.

For importing options see MooseX::Types.

=cut

use Moose::Util::TypeConstraints;
use MooseX::Types::Structured(':all');
use MooseX::Types::Moose(':all');
use POEx::WorkerPool::WorkerEvents(':all');

use MooseX::Types -declare =>
[
    'DoesWorker',
    'DoesWorkerPool',
    'DoesWorkerGuts',
    'DoesJob',
    'WorkerEvent',
    'JobStatus',
    'JobStep',
];


=head1 TYPES

=head2 DoesWorker

Must compose the POEx::WorkerPool::Role::WorkerPool::Worker role.

=cut

subtype DoesWorker,
    as 'Moose::Object',
    where { $_->does('POEx::WorkerPool::Role::WorkerPool::Worker') };

=head2 DoesWorkerPool

Must compose the POEx::WorkerPool::Role::WorkerPool role.

=cut

subtype DoesWorkerPool,
    as 'Moose::Object',
    where { $_->does('POEx::WorkerPool::Role::WorkerPool') };

=head2 DoesWorkerGuts

Must compose the POEx::WorkerPool::Role::WorkerPool::Worker::Guts role.

=cut

subtype DoesWorkerGuts,
    as 'Moose::Object',
    where { $_->does('POEx::WorkerPool::Role::WorkerPool::Worker::Guts') };

=head2 DoesJob

Must compose the POEx::WorkerPool::Role::WorkerPool::Job role.

=cut

subtype DoesJob,
    as 'Moose::Object',
    where { $_->does('POEx::WorkerPool::Role::Job') };

=head2 WorkerEvent

Must be one of the worker events defined in POEx::WorkerPool::WorkerEvents

=cut

subtype WorkerEvent,
    as enum
    (
        [
            +PXWP_WORKER_CHILD_ERROR,
            +PXWP_WORKER_CHILD_EXIT,
            +PXWP_JOB_ENQUEUED,
            +PXWP_START_PROCESSING,
            +PXWP_JOB_DEQUEUED,
            +PXWP_STOP_PROCESSING,
            +PXWP_WORKER_INTERNAL_ERROR,
            +PXWP_JOB_COMPLETE,
            +PXWP_JOB_PROGRESS,
            +PXWP_JOB_FAILED,
            +PXWP_JOB_START,
            +PXWP_JOB_COMPLETE,
        ]
    );

=head2 JobStatus

JobStatus is what a Worker::Guts composed object must return. It consistes of 
a hash with three keys and potential forth depending on type. See below:

    {
        type => WorkerEvent,
        ID => Str,
        msg => Ref,
        percent_complete => Maybe[Int]
    }

percent_complete is only valid when type is +PXWP_JOB_PROGRESS

=cut

subtype JobStatus,
    as Dict
    [
        type => WorkerEvent,
        ID => Str,
        msg => Ref,
        percent_complete => Maybe[Int]
    ],
    where
    {
        if($_->{type} eq +PXWP_JOB_PROGRESS)
        {
            return exists($_->{percent_complete}) && defined($_->{percent_complete});
        }

        return 1;
    };

=head2 JobStep

When constructing Jobs, each step must match a Tuple[CodeRef, ArrayRef] where
the code ref is the actual thing to execute and the array ref is the collection
of arguments to be passed to the code ref verbatim.

=cut

subtype JobStep,
    as Tuple[CodeRef, ArrayRef];

1;
__END__
