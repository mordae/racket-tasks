#lang racket/base
;
; Task Server
;

(require racket/contract
         racket/function
         racket/async-channel)

(provide (except-out (all-defined-out) task-server))


(define-struct task-server
  (queue
   timers
   events)
  #:constructor-name task-server
  #:mutable)


(define/contract (make-task-server)
                 (-> task-server?)
  (task-server (make-async-channel) (make-hasheq) (make-hasheq)))


(define current-task-server
  (make-parameter (make-task-server)))


(define/contract (call-with-task-server proc)
                 (-> (-> any) any)
  (parameterize ((current-task-server (make-task-server)))
    (proc)))


(define/contract (run-tasks (task-server #f))
                 (->* () ((or/c #f task-server?)) void?)
  (let* ((task-server (or task-server (current-task-server)))
         (queue       (task-server-queue task-server))
         (timers      (task-server-timers task-server))
         (events      (task-server-events task-server)))

    (define (self-wrap evt)
      (wrap-evt evt (lambda (result)
                      (cons evt result))))

    (define (next)
      (sync queue (apply choice-evt (hash-keys timers))
                  (apply choice-evt (map self-wrap (hash-keys events)))))

    (for ((task (in-producer next #f)))
      (cond
        ((hash-has-key? timers task)
         (let ((real-task (hash-ref timers task)))
           (hash-remove! timers task)
           (real-task)))

        ((pair? task)
         (let ((real-task (hash-ref events (car task))))
           (real-task (cdr task))))

        (else
         (task))))))


(define/contract (schedule-stop-task (task-server #f))
                 (->* () ((or/c #f task-server?)) void?)
  (let ((queue (task-server-queue (or task-server (current-task-server)))))
    (async-channel-put queue #f)))


(define/contract (schedule-task proc (task-server #f))
                 (->* ((-> any)) ((or/c #f task-server?)) void?)
  (let ((queue (task-server-queue (or task-server (current-task-server)))))
    (async-channel-put queue proc)))


(define/contract (schedule-delayed-task proc secs (task-server #f))
                 (->* ((-> any) integer?) ((or/c #f task-server?)) void?)
  (let ((task-server (or task-server (current-task-server))))
    (hash-set! (task-server-timers task-server)
               (alarm-evt (+ (current-inexact-milliseconds) (* 1000 secs)))
               proc)))


(define/contract (schedule-recurring-task proc secs (task-server #f))
                 (->* ((-> any) integer?) ((or/c #f task-server?)) void?)
  (define (wrapper)
    (schedule-delayed-task wrapper secs task-server)
    (proc))

  (wrapper))


(define/contract (schedule-sync-task proc evt (task-server #f))
                 (->* ((-> any/c any) evt?) ((or/c #f task-server?)) void?)
  (let ((task-server (or task-server (current-task-server))))
    (hash-set! (task-server-events task-server) evt proc)))


(define-syntax-rule (with-task-server body ...)
  (call-with-task-server
    (thunk body ...)))


(define-syntax-rule (task body ...)
  (schedule-task
    (thunk body ...)))


(define-syntax-rule (recurring-task delay body ...)
  (schedule-recurring-task
    (thunk body ...) delay))


(define-syntax-rule (delayed-task delay body ...)
  (schedule-delayed-task
    (thunk body ...) delay))


(define-syntax-rule (sync-task (name event) body ...)
  (schedule-sync-task
    (lambda (name)
      body ...)
    event))


; vim:set ts=2 sw=2 et:
