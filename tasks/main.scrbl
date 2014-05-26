#lang scribble/manual

@require[(for-label racket)
         (for-label "main.rkt")]

@title{Task Server}
@author+email["Jan Dvořák" "mordae@anilinux.org"]

Enables event-driven programming using a central poller and a number of
callback procedures.


@defmodule[tasks]


@section{Functions}

@defproc[(task-server) task-server?]{
  Create new task server to pass along.

  There is a default task server, so if you are not doing anything
  serious you can just use the functions below.  It's almost always
  better to use @racket[call-with-task-server] or the
  @racket[with-task-server] form instead if you really need one.
}

@defproc[(task-server? (v any/c)) boolean?]{
  Predicate identifying a task server.
}

@defproc[(call-with-task-server (proc (-> any))) any]{
  Call specified procedure @racket[proc] with new
  @racket[current-task-server].
}

@defparam[current-task-server task-server task-server?]{
  Parameter identifying default task server for the procedures below.
}

@defproc[(run-tasks (task-server task-server? (current-task-server)))
         void?]{
  Enter the main loop, waiting for and executing defined tasks.
  To terminate the loop use @racket[schedule-stop-task].
}

@defproc[(schedule-stop-task (task-server task-server? (current-task-server)))
         void?]{
  Schedule task that will stop the task server at some close time or
  immediately if there are no other tasks scheduled.
}

@defproc[(schedule-task (proc (-> any))
                        (task-server task-server? (current-task-server)))
         void?]{
  Schedule specified procedure @racket[proc] to be executed soon.
}

@defproc[(schedule-delayed-task (proc (-> any))
                                (secs real?)
                                (task-server task-server?
                                  (current-task-server)))
         void?]{
  Schedule specified procedure @racket[proc] to be executed after at least
  specified number of seconds, defined by @racket[spec].
}

@defproc[(schedule-recurring-task (proc (-> any))
                                  (secs real?)
                                  (task-server task-server?
                                    (current-task-server)))
         void?]{
  Schedule specified procedure @racket[proc] to be executed periodically,
  with specified @racket[secs] interval, starting soon after the call.
}

@defproc[(schedule-event-task (proc procedure?)
                              (evt evt?)
                              (task-server task-server (current-task-server)))
         void?]{
  Schedule specified procedure @racket[proc] to be executed when specified
  event source @racket[evt] becomes ready for synchronization.
  Synchronization result will form @racket[proc] arguments.
}

@defproc[(schedule-recurring-event-task (proc procedure?)
                                        (evt evt?)
                                        (task-server task-server
                                          (current-task-server)))
         void?]{
  Schedule specified procedure @racket[proc] to be execute every time
  specified event source @racket[evt] becomes ready for synchronization.
  Synchronization result will form @racket[proc] arguments.
}



@section{Syntactic Forms}

@defform[(with-task-server body ...)]{
  Shortcut for @racket[(call-with-task-server (λ () body ...))].
}

@defform[(stop-task)]{
  Shortcut for @racket[(schedule-stop-task)].
}

@defform[(task body ...)]{
  Shortcut for @racket[(schedule-task (λ () body ...))].
}

@defform[(recurring-task delay body ...)]{
  Shortcut for @racket[(schedule-recurring-task (λ () body ...) delay)].
}

@defform[(delayed-task delay body ...)]{
  Shortcut for @racket[(schedule-delayed-task (λ () body ...) delay)].
}

@defform[(event-task (evt . args) body ...)]{
  Shortcut for @racket[(schedule-event-task (λ args body ...) evt)].
}

@defform[(recurring-event-task (evt . args) body ...)]{
  Shortcut for @racket[(schedule-recurring-event-task (λ args body ...) evt)].
}


@; vim:set ft=scribble sw=2 ts=2 et:
