# Task Server

Enables event-driven programming using a central poller and a number of
callback procedures.


## Example

    (with-task-server
      (define ch (make-async-channel))
      (define i 0)

      (task
        (printf "simple async task\n"))

      (recurring-task 2
        (set! i (add1 i))
        (printf "~s. this task runs every 2 seconds\n" i)
        (async-channel-put ch i))

      (recurring-event-task (ch value)
        (printf "received value: ~s\n" value))

      (event-task (always-evt _)
        (async-channel-put ch 'once))

      (run-tasks))
