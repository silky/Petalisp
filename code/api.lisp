;;; © 2016 Marco Heisig - licensed under AGPLv3, see the file COPYING

(in-package :petalisp)

(defun α (operator object &rest more-objects)
  (let* ((objects
           (mapcar #'lisp->petalisp (list* object more-objects)))
         (index-space
           (reduce #'broadcast objects))
         (objects
           (mapcar
            (lambda (object)
              (repetition object index-space))
            objects))
         (operator (find-operator operator)))
    (apply #'application operator objects)))

(defun β (operator object)
  (reduction operator object))

(defun fuse (object &rest more-objects)
  (let* ((objects (list* object more-objects))
         (current ())
         (new ()))
    (dolist (b objects)
      (let ((b-intersects nil))
        (dolist (a current)
          (let ((a∩b (intersection a b)))
            (cond
              ((not a∩b) (push a new))
              (t
               (setf b-intersects t)
               (push (reference b a∩b TODO) new)
               (dolist (difference (difference a b))
                 (push (reference a difference TODO) new))
               (dolist (difference (difference b a))
                 (push (reference b difference TODO) new))))))
        (unless b-intersects (push b new)))
      (psetf current new new ()))
    (apply #'fusion current)))

(defun repeat (object space)
  (repetition object space))

(defun ← (object &rest subspaces-and-transformations)
    (let ((target-space (index-space object))
          (transformation (identity-transformation (dimension object))))
      (dolist (x subspaces-and-transformations)
        (etypecase x
          (transformation
           (zapf target-space (transform % x))
           (zapf transformation (compose x %)))
          (index-space
           (assert (subspace? x target-space))
           (setf target-space x))))
      (let ((source-space (transform target-space (invert transformation))))
        (reference object source-space transformation))))

(defmacro subspace (space &rest dimensions)
  (with-gensyms (dim)
    (once-only (space)
      `(symbol-macrolet
           ((,(intern "START") (range-start (aref (ranges ,space) ,dim)))
            (,(intern "STEP") (range-step (aref (ranges ,space) ,dim)))
            (,(intern "END") (range-end (aref (ranges ,space) ,dim))))
         (make-index-space
          ,@(loop for form in dimensions and d from 0
                  collect `(let ((,dim ,d)) (range ,@form))))))))

(defmacro σ (&rest ranges)
  `(make-index-space
    ,@(loop for range in ranges
            collect `(range ,@range))))

(defmacro τ (symbols mappings)
  `(classify-transformation
    (lambda ,symbols (values ,@mappings))
    ,(length symbols)
    ,(length mappings)))

(defun classify-transformation (f nargin nargout)
  (or
   (function->affine-transformation f nargin nargout)
   (function->identity-transformation f nargin nargout)
   (error "Invalid transformation.")))

(defun function->identity-transformation (f input-dimension output-dimension)
  (declare (ignore output-dimension))
  (let ((args
          (list
           (make-list input-dimension :initial-element 0)
           (make-list input-dimension :initial-element 1)
           (iota input-dimension))))
    (loop for x in args
          always (equal (multiple-value-list (apply f x)) x)
          finally (identity-transformation input-dimension))))

(defun function->affine-transformation (f input-dimension output-dimension)
  (let ((args
          (list
           (make-list input-dimension :initial-element 0)
           (make-list input-dimension :initial-element 1)
           (iota input-dimension))))
    (loop for x in args
          always (equal x (multiple-value-list (apply f x)))
          finally (return
                    (identity-transformation input-dimension)))))
