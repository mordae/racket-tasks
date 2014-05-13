#lang racket/base
;
; Task Server
;

(require racket/contract
         racket/function
         racket/async-channel)

(provide (except-out (all-defined-out)
                     task-server task-server-queue task-server-events))


(define-struct task-server
  (queue
   events)
  #:constructor-name task-server
  #:mutable)


(define/contract (make-task-server)
                 (-> task-server?)
  (task-server (make-async-channel) (make-hasheq)))


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
         (events      (task-server-events task-server)))

    (define (next)
      (apply sync queue (hash-keys events)))

    (for ((task (in-producer next #f)))
      (cond
        ((pair? task)
         (let ((real-task (hash-ref events (car task))))
           (hash-remove! events (car task))
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
  (let ((task-server (or task-server (current-task-server)))
        (alarm (alarm-evt (+ (current-inexact-milliseconds) (* 1000 secs)))))
    (schedule-event-task (lambda (alarm) (proc)) alarm)))


(define/contract (schedule-recurring-task proc secs (task-server #f))
                 (->* ((-> any) integer?) ((or/c #f task-server?)) void?)
  (define (wrapper)
    (schedule-delayed-task wrapper secs task-server)
    (proc))

  (schedule-task wrapper))


(define/contract (schedule-event-task proc evt (task-server #f))
                 (->* ((-> any/c any) evt?) ((or/c #f task-server?)) void?)
  (define wrapped-evt (wrap-evt evt (lambda (result)
                                      (cons wrapped-evt result))))
  (let ((events (task-server-events (or task-server (current-task-server)))))
    (hash-set! events wrapped-evt proc)))


(define/contract (schedule-recurring-event-task proc evt (task-server #f))
                 (->* ((-> any/c any) evt?) ((or/c #f task-server?)) void?)
  (define (wrapper result)
    (schedule-event-task wrapper evt task-server)
    (proc result))

  (schedule-event-task wrapper evt task-server))


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


(define-syntax-rule (event-task (name event) body ...)
  (schedule-event-task
    (lambda (name)
      body ...)
    event))


(define-syntax-rule (recurring-event-task (name event) body ...)
  (schedule-recurring-event-task
    (lambda (name)
      body ...)
    event))


; vim:set ts=2 sw=2 et:
