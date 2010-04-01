package POEx::WorkerPool::Role::WorkerPool::Worker::GutsLoader;

#ABSTRACT: Implementation role of the Guts loader

use MooseX::Declare;

role POEx::WorkerPool::Role::WorkerPool::Worker::GutsLoader
{
    use POE;
    use Class::MOP;
    use POEx::WorkerPool::Worker::Guts;
    use MooseX::Types;
    use MooseX::Types::Moose(':all');

=attribute_public job_classes

 is: ro, isa: ArrayRef[ClassName], required: 1

These are the job classes should be loaded during init using
Class::MOP::load_class

=cut

    has job_classes => ( is => 'ro', isa => ArrayRef[ClassName], required => 1 );

=attribute_public init

 is: ro, isa: CodeRef, lazy_build: 1

This holds the coderef that will be executed first to do any intitialization
prior to building the Guts session

=cut

    has init => ( is => 'ro', isa => CodeRef, lazy_build => 1 );

=attribute_public preamble

 is: ro, isa: CodeRef, lazy_build: 1

This holds the coderef that is responsible for stopping the forked POE::Kernel
singleton

=cut

    has preamble => ( is => 'ro', isa => CodeRef, lazy_build => 1 );

=attribute_public main

 is: ro, isa: CodeRef, lazy_build: 1

This holds the coderef that builds the actual Guts

=cut

    has main => ( is => 'ro', isa => CodeRef, lazy_build => 1 );

=attribute_public prologue

 is: ro, isa: CodeRef, lazy_build: 1

This holds the coderef that calls run() on POE::Kernel to kickstart everything

=cut

    has prologue => ( is => 'ro', isa => CodeRef, lazy_build => 1 );

=attribute_public loader

 is: ro, isa: CodeRef, lazy_build: 1

loader has the coderef that is used when building the POE::Wheel::Run instance
inside of Worker's child_wheel attribute. The coderef is actually an aggregate
of init, preamble, main, and prologue.

=cut

    has loader => ( is => 'ro', isa => CodeRef, lazy_build => 1 );

=method_protected _build_init

_build_init builds the coderef used for initialization of the job classes in
the child process.

=cut

    method _build_init
    {
        my $classes = $self->job_classes;
        return sub
        {
            Class::MOP::load_class($_) for @$classes;
        };
    }

=method_protected _build_preamble

_build_preamble builds the coderef that calls stop on POE::Kernel by default.

=cut

    method _build_preamble
    {
        return sub
        {
            POE::Kernel->stop();
        };
    }

=method_protected _build_main

_build_main builds the coderef that instantiates the Guts instance without any
arguments. If Guts has other roles applied at compile time that require extra
arguments, this method will need to be advised to provide those arguments to
the constructor.

=cut

    method _build_main
    {
        return sub
        {
            POEx::WorkerPool::Worker::Guts->new();
        };
    }

=method_protected _build_prologue

_build_prologue builds the coderef that calls run() on POE::Kernel by default.

=cut

    method _build_prologue
    {
        return sub
        {
            POE::Kernel->run();
        };
    }

=method_protected _build_loader

_build_loader builds the coderef that is passed to the POE::Wheel::Run
constructor inside of Worker's child_wheel attribute builder. It creates a
closure around lexical references to init, preamble, main, and prologue, that
executes said coderefs in that order.

=cut

    method _build_loader
    {
        my $init = $self->init;
        my $preamble = $self->preamble;
        my $main = $self->main;
        my $prologue = $self->prologue;

        return sub
        {
            $init->();
            $preamble->();
            $main->();
            $prologue->();
        };
    }
}

1;
__END__
