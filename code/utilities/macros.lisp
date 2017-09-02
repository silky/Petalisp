;;; © 2016-2017 Marco Heisig - licensed under AGPLv3, see the file COPYING

(in-package :petalisp)

(defmacro λ (&rest symbols-and-expr)
  "A shorthand notation for lambda expressions, provided your Lisp
implementation is able to treat λ as a character.

Examples:
 (λ x x) -> (lambda (x) x)
 (λ x y (+ x y)) -> (lambda (x y) (+ x y))"
  `(lambda ,(butlast symbols-and-expr)
     ,@(last symbols-and-expr)))

(defmacro with-unsafe-optimizations* (&body body)
  "Optimize the heck out of BODY. Use with caution!"
  `(locally
       (declare
        (optimize (speed 3) (space 0) (debug 0) (safety 0) (compilation-speed 0)))
     ,@body))

(defmacro with-unsafe-optimizations (&body body)
  "Optimize the heck out of BODY. Use with caution!

To preserve sanity, compiler efficiency hints are disabled by default. Use
WITH-UNSAFE-OPTIMIZATIONS* to see these hints."
  `(locally (declare #+sbcl(sb-ext:muffle-conditions sb-ext:compiler-note))
     (with-unsafe-optimizations* ,@body)))

(defmacro let/de (bindings &body body)
  "Like LET, but declare every atom to have dynamic extent."
  `(let ,bindings
     (declare (dynamic-extent ,@(mapcar #'first bindings)))
     ,@body))

(defmacro define-class (class-name superclass-names slot-specifiers &rest class-options)
  "Defines a class using DEFCLASS, but defaulting to a :READER of
SLOT-NAME and. Additionally, defines a <NAME>? predicate."
  (flet ((extend-slot-specifier (slot-specifier)
           (destructuring-bind (slot-name &rest plist)
               (ensure-list slot-specifier)
             (let ((initarg (unless (getf plist :initarg)
                              (list :initarg (make-keyword slot-name))))
                   (reader (unless (or (getf plist :reader)
                                       (getf plist :accessor)
                                       (getf plist :writer))
                             (list :reader slot-name))))
               `(,slot-name ,@initarg ,@reader ,@plist)))))
    `(progn
       (defclass ,class-name ,superclass-names
         ,(mapcar #'extend-slot-specifier slot-specifiers)
         ,@class-options)
       (declaim (inline ,(symbolicate class-name "?")))
       (defun ,(symbolicate class-name "?") (x)
         (typep x ',class-name)))))

(defmacro zapf (place expr)
  (multiple-value-bind
        (temps exprs stores store-expr access-expr)
      (get-setf-expansion place)
    `(let* (,@(mapcar #'list temps exprs)
            (,(car stores)
              (let ((% ,access-expr))
                ,expr)))
       ,store-expr)))