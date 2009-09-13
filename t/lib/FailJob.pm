use MooseX::Declare;

my $STEPS = 0;
class FailJob with POEx::WorkerPool::Role::Job
{
    method import(ClassName $class: Maybe[Int] :$steps)
    {
        $STEPS = $steps if defined($steps);
    }

    method init_job
    {
        foreach my $step (1..$STEPS)
        {
            $self->enqueue_step
            (
                [
                    sub { map { int(rand(10)) * $_ } @_; die if $step == 2; },
                    [0..99]
                ],
            );
        }
    }
}

