#lang racket/base
;
; Task Server
;
; Enables event-driven programming using a central poller and
; a number of callback procedures.
;

(require racket/contract
         racket/set)

(provide
  (contract-out
    (task-server? predicate/c)
    (rename make-task-server task-server (-> task-server?))
    (current-task-server (parameter/c task-server?))
    (call-with-task-server (-> (-> any) any))
    (run-tasks (->* () (task-server?) void?))
    (schedule-stop-task (->* () (task-server?) void?))
    (schedule-task (->* ((-> any)) (task-server?) void?))
    (schedule-delayed-task (->* ((-> any) real?) (task-server?) void?))
    (schedule-recurring-task (->* ((-> any) real?) (task-server?) void?))
    (schedule-recurring-event-task (->* (procedure? evt?) (task-server?) void?))
    (schedule-event-task (->* (procedure? evt?) (task-server?) void?))))

(provide
  with-task-server
  stop-task
  task
  delayed-task
  recurring-task
  event-task
  recurring-event-task)


(struct task-server
  (refresh stop events))


(define (make-task-server)
  (task-server (make-semaphore) (make-semaphore) (mutable-seteq)))


(define current-task-server
  (make-parameter (make-task-server)))


(define (call-with-task-server proc)
  (parameterize ((current-task-server (make-task-server)))
    (proc)))


(define (run-tasks (task-server (current-task-server)))
  (define refresh (task-server-refresh task-server))
  (define stop    (task-server-stop    task-server))
  (define events  (task-server-events  task-server))

  (define (next)
    (apply sync refresh stop (set->list events)))

  (for ((evt (in-producer next stop)))
    (void)))


(define (schedule-stop-task (task-server (current-task-server)))
  (semaphore-post (task-server-stop task-server)))


(define (schedule-event-task proc evt (task-server (current-task-server)))
  (define refresh (task-server-refresh task-server))
  (define events  (task-server-events task-server))

  (define wrapped-evt
    (handle-evt evt (λ args
                      (set-remove! events wrapped-evt)
                      (apply proc args))))

  (set-add! events wrapped-evt)
  (semaphore-post refresh))


(define (schedule-recurring-event-task proc evt (task-server
                                                  (current-task-server)))
  (define (recurring-wrapper . results)
    (schedule-event-task recurring-wrapper evt task-server)
    (apply proc results))

  (schedule-event-task recurring-wrapper evt task-server))


(define (schedule-task proc (task-server (current-task-server)))
  (schedule-event-task (λ _ (proc)) always-evt task-server))


(define (schedule-delayed-task proc secs (task-server (current-task-server)))
  (let ((at (+ (current-inexact-milliseconds) (* 1000 secs))))
    (schedule-event-task (λ _ (proc)) (alarm-evt at) task-server)))


(define (schedule-recurring-task proc secs (task-server (current-task-server)))
  (define (recurring-wrapper)
    (schedule-delayed-task recurring-wrapper secs task-server)
    (proc))

  (schedule-task recurring-wrapper task-server))


(define-syntax-rule (with-task-server body ...)
  (call-with-task-server
    (λ () body ...)))


(define-syntax-rule (stop-task)
  (schedule-stop-task))


(define-syntax-rule (task body ...)
  (schedule-task
    (λ () body ...)))


(define-syntax-rule (recurring-task delay body ...)
  (schedule-recurring-task
    (λ () body ...) delay))


(define-syntax-rule (delayed-task delay body ...)
  (schedule-delayed-task
    (λ () body ...) delay))


(define-syntax-rule (event-task (evt . args) body ...)
  (schedule-event-task (λ args body ...) evt))


(define-syntax-rule (recurring-event-task (evt . args) body ...)
  (schedule-recurring-event-task (λ args body ...) evt))


; vim:set ts=2 sw=2 et:
