use MooseX::Declare;

my $STEPS = 0;
class MyJob with POEx::WorkerPool::Role::Job
{
    method import(ClassName $class: Maybe[Int] :$steps)
    {
        $STEPS = $steps if defined($steps);
    }

    method init_job
    {
        for(1..$STEPS)
        {
            $self->enqueue_step
            (
                [
                    sub { map { int(rand(10)) * $_ } @_ },
                    [0..99]
                ],
            );
        }
    }
}

