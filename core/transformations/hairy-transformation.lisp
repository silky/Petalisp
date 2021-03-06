;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING

(uiop:define-package :petalisp/core/transformations/hairy-transformation
  (:use :closer-common-lisp :alexandria)
  (:use
   :petalisp/utilities/all
   :petalisp/core/error-handling
   :petalisp/core/transformations/transformation
   :petalisp/core/transformations/invertible-transformation)
  (:export
   #:hairy-transformation
   #:hairy-invertible-transformation
   #:translation
   #:permutation
   #:scaling))

(in-package :petalisp/core/transformations/hairy-transformation)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Classes

(defclass hairy-transformation (transformation)
  ((%input-dimension :initarg :input-dimension
                     :reader input-dimension
                     :type unsigned-byte)
   (%output-dimension :initarg :output-dimension
                      :reader output-dimension
                      :type unsigned-byte)
   ;; The slots %INPUT-CONSTRAINTS, %TRANSLATION, %PERMUTATION and %SCALING
   ;; are either nil or a suitable simple vector. The number of slots of
   ;; many transformations could be reduced by introducing separate classes
   ;; for the nil case and the simple vector case. However, this would
   ;; amount to 2^4 = 16 classes and a lot of added complexity. So we
   ;; remain with a single class HAIRY-TRANSFORMATION to cover all these
   ;; cases.
   (%input-constraints :initarg :input-constraints
                       :reader input-constraints
                       :initform nil
                       :type (or null simple-vector))
   (%translation :initarg :translation
                 :reader translation
                 :initform nil
                 :type (or null simple-vector))
   (%permutation :initarg :permutation
                 :reader permutation
                 :initform nil
                 :type (or null simple-vector))
   (%scaling :initarg :scaling
             :reader scaling
             :initform nil
             :type (or null simple-vector)))
  (:metaclass funcallable-standard-class))

(defclass hairy-invertible-transformation
    (hairy-transformation
     invertible-transformation
     cached-inverse-transformation-mixin)
  ()
  (:metaclass funcallable-standard-class))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Handling of (or null simple-vector) Arrays

(defmacro with-duplicate-body (condition definitions &body body)
  (loop for (name lambda-list true-body false-body) in definitions
        collect `(,name ,lambda-list
                        (declare (ignorable ,@lambda-list))
                        ,true-body)
          into true-defs
        collect `(,name ,lambda-list
                        (declare (ignorable ,@lambda-list))
                        ,false-body)
          into false-defs
        finally
           (return
             `(if ,condition
                  (macrolet ,true-defs ,@body)
                  (macrolet ,false-defs ,@body)))))

;;; Replicate BODY 16 times for all the different possible array states.
(defmacro with-hairy-transformation-refs
    ((&key
        ((:input-constraints cref))
        ((:translation tref))
        ((:permutation pref))
        ((:scaling sref)))
     transformation &body body)
  (once-only (transformation)
    (with-gensyms (input-constraints translation permutation scaling)
      `(let ((,input-constraints (input-constraints ,transformation))
             (,translation (translation ,transformation))
             (,permutation (permutation ,transformation))
             (,scaling (scaling ,transformation)))
         (with-duplicate-body (null ,input-constraints)
             ((,cref (index) nil `(the (or null integer) (aref ,',input-constraints ,index))))
           (with-duplicate-body (null ,translation)
               ((,tref (index) 0 `(the rational (aref ,',translation ,index))))
             (with-duplicate-body (null ,permutation)
                 ((,pref (index) index `(the (or null array-index) (aref ,',permutation ,index))))
               (with-duplicate-body (null ,scaling)
                   ((,sref (index) 1 `(the rational (aref ,',scaling ,index))))
                 ,@body))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods

(defmethod transformation-equal
    ((transformation-1 hairy-transformation)
     (transformation-2 hairy-transformation))
  (and (= (input-dimension transformation-1)
          (input-dimension transformation-2))
       (= (output-dimension transformation-1)
          (output-dimension transformation-2))
       (equalp (input-constraints transformation-1)
               (input-constraints transformation-2))
       (equalp (translation transformation-1)
               (translation transformation-2))
       (equalp (permutation transformation-1)
               (permutation transformation-2))
       (equalp (scaling transformation-1)
               (scaling transformation-2))))

(defmethod compose-transformations
    ((g hairy-transformation) (f hairy-transformation))
  ;; A2 (A1 x + b1) + b2 = A2 A1 x + A2 b1 + b2
  (let ((input-dimension (input-dimension f))
        (output-dimension (output-dimension g)))
    (let ((input-constraints
            (if-let ((input-constraints (input-constraints f)))
              (copy-array input-constraints)
              (make-array input-dimension :initial-element nil)))
          (permutation
            (make-array output-dimension :initial-element nil))
          (scaling
            (make-array output-dimension :initial-element 0))
          (translation
            (make-array output-dimension :initial-element 0)))
      (with-hairy-transformation-refs
          (:input-constraints iref
           :permutation pref
           :scaling sref
           :translation tref)
          f
        (flet ((set-output (output-index input-index a b)
                 (cond ((null input-index)
                        (setf (aref scaling output-index) b))
                       ((and)
                        (setf (aref permutation output-index)
                              (pref input-index))
                        (setf (aref scaling output-index)
                              (* a (sref input-index)))
                        (setf (aref translation output-index)
                              (+ (* a (tref input-index)) b))))))
          (map-transformation-outputs g #'set-output)))
      (make-transformation
       :input-dimension input-dimension
       :output-dimension output-dimension
       :input-constraints input-constraints
       :permutation permutation
       :scaling scaling
       :translation translation))))

(defmethod invert-transformation
    ((transformation hairy-invertible-transformation))
  ;;    f(x) = (Ax + b)
  ;; f^-1(x) = A^-1(x - b) = A^-1 x - A^-1 b
  (let ((output-dimension (input-dimension transformation))
        (input-dimension (output-dimension transformation))
        (original-input-constraints (input-constraints transformation)))
    (let ((input-constraints
            (make-array input-dimension :initial-element nil))
          (permutation
            (make-array output-dimension :initial-element nil))
          (scaling
            (make-array output-dimension :initial-element 0))
          (translation
            (if (not original-input-constraints)
                (make-array output-dimension :initial-element 0)
                (copy-array (input-constraints transformation)))))
      (flet ((set-inputs (output-index input-index a b)
               (cond
                 ((not input-index)
                  (setf (aref input-constraints output-index) b))
                 ((/= 0 a)
                  (setf (aref permutation input-index) output-index)
                  (setf (aref scaling input-index) (/ a))
                  (setf (aref translation input-index) (- (/ b a)))))))
        (map-transformation-outputs transformation #'set-inputs))
      (make-transformation
       :input-dimension input-dimension
       :output-dimension output-dimension
       :input-constraints input-constraints
       :permutation permutation
       :scaling scaling
       :translation translation))))

(defmethod enlarge-transformation
    ((transformation hairy-transformation) scale offset)
  (let ((input-dimension (1+ (input-dimension transformation)))
        (output-dimension (1+ (output-dimension transformation)))
        (old-constraints (input-constraints transformation))
        (old-translation (translation transformation))
        (old-scaling (scaling transformation))
        (old-permutation (permutation transformation)))
    (let ((input-constraints (make-array input-dimension))
          (permutation       (make-array output-dimension))
          (scaling           (make-array output-dimension))
          (translation       (make-array output-dimension)))
      (if (not old-constraints)
          (fill input-constraints nil)
          (replace input-constraints old-constraints))
      (if (not old-permutation)
          (loop for index below output-dimension do
            (setf (aref permutation index) index))
          (replace permutation old-permutation))
      (if (not old-scaling)
          (loop for index below output-dimension
                for p across permutation do
            (setf (aref scaling index)
                  (if (not p) 0 1)))
          (replace scaling old-scaling))
      (if (not old-translation)
          (fill translation 0)
          (replace translation old-translation))
      (setf (aref input-constraints (1- input-dimension)) nil)
      (setf (aref permutation       (1- output-dimension)) (1- input-dimension))
      (setf (aref scaling           (1- output-dimension)) scale)
      (setf (aref translation       (1- output-dimension)) offset)
      (make-transformation
       :input-dimension input-dimension
       :output-dimension output-dimension
       :input-constraints input-constraints
       :permutation permutation
       :scaling scaling
       :translation translation))))

(defmethod generic-unary-funcall :before
    ((transformation hairy-transformation)
     (s-expressions list))
  (when-let ((input-constraints (input-constraints transformation)))
    (loop for s-expression in s-expressions
          for constraint across input-constraints
          for index from 0 do
            (unless (not constraint)
              (when (numberp s-expression)
                (demand (= s-expression constraint)
                  "~@<The number ~W violates the ~:R input constraint ~
                      of the transformation ~W.~:@>"
                  s-expression index transformation))))))

(defmethod generic-unary-funcall
    ((transformation hairy-transformation)
     (s-expressions list))
  (let ((result '()))
    (flet ((push-output-expression (output-index input-index a b)
             (declare (ignore output-index))
             (let* ((x (if (not input-index)
                           0
                           (elt s-expressions input-index)))
                    (a*x (cond ((= 1 a) x)
                               ((numberp x) (* a x))
                               ((and) `(* ,a ,x))))
                    (a*x+b (cond ((eql a*x 0) b)
                                 ((= b 0) a*x)
                                 ((numberp a*x) (+ a*x b))
                                 ((= b  1) `(1+ ,a*x))
                                 ((= b -1) `(1- ,a*x))
                                 ((and) `(+ ,a*x ,b)))))
               (push A*x+b result))))
      (map-transformation-outputs transformation #'push-output-expression)
      (nreverse result))))

(defmethod map-transformation-outputs
    ((transformation hairy-transformation)
     (function function))
  (let ((output-dimension (output-dimension transformation)))
    (with-hairy-transformation-refs
        (:input-constraints cref
         :scaling sref
         :permutation pref
         :translation tref)
        transformation
      (loop for output-index below output-dimension
            for input-index = (pref output-index)
            for scaling = (sref output-index)
            for offset = (tref output-index) do
              (funcall function output-index input-index scaling offset)))))
