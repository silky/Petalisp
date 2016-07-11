;;; © 2016 Marco Heisig - licensed under AGPLv3, see the file COPYING

(in-package :petalisp)

(defclass strided-array-source (strided-array source) ()
  (:documentation
   "A Petalisp object that returns the same value for all indices."))

(defclass strided-array-from-lisp-array
    (strided-array-source)
  ((%lisp-array :initarg :lisp-array :reader lisp-array)))

(defclass strided-array-from-lisp-scalar
    (strided-array-source)
  ((%object :initarg :object :reader object)))

(defmethod generic-source ((object t) &rest arguments)
  (let ((ranges (when arguments (ranges (first arguments)))))
    (make-instance
     'strided-array-from-lisp-scalar
     :object object
     :ranges ranges)))

(defmethod generic-source ((object array) &rest arguments)
  (assert (null arguments))
  (make-instance
   'strided-array-from-lisp-array
   :object object
   :ranges ())) ;; TODO

(defun |#i-reader| (stream subchar arg)
  (declare (ignore subchar arg))
  `(make-instance
    'strided-array-index-space
    :ranges
    (list ,@(loop for spec in (read stream t nil t)
                  collect
                  (if (atom spec)
                      `(range ,spec)
                      `(range ,@spec))))))

 (set-dispatch-macro-character #\# #\i #'|#i-reader|)