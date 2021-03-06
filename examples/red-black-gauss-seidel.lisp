(in-package :common-lisp-user)

(defpackage :petalisp/examples/red-black-gauss-seidel
  (:use :cl :petalisp)
  (:export #:red-black-gauss-seidel))

(in-package :petalisp/examples/red-black-gauss-seidel)

(defun red-black-gauss-seidel (u &key (iterations 1)
                                   (h (/ (1- (expt (size u) (/ (dimension u))))))
                                   (f 0))
  "Iteratively solve the Poisson equation -Δu = f for a given uniform grid
  with spacing h, using the Red-Black Gauss-Seidel scheme."
  (ecase (dimension u)
    (1 (let ((r (σ* u ((+ start 2) 2 (1- end))))
             (b (σ* u ((+ start 1) 2 (1- end)))))
         (labels ((update (u what)
                    (α #'* (float 1/2)
                       (α #'+
                          (-> u (τ (i) ((1+ i))) what)
                          (-> u (τ (i) ((1- i))) what)
                          (-> (α #'* (* h h) f) what)))))
           (loop repeat iterations do
             (setf u (fuse* u (update u r)))
             (setf u (fuse* u (update u b))))
           u)))
    (2 (let ((r1 (σ* u ((+ start 2) 2 (1- end)) ((+ start 2) 2 (1- end))))
             (r2 (σ* u ((+ start 1) 2 (1- end)) ((+ start 1) 2 (1- end))))
             (b1 (σ* u ((+ start 2) 2 (1- end)) ((+ start 1) 2 (1- end))))
             (b2 (σ* u ((+ start 1) 2 (1- end)) ((+ start 2) 2 (1- end)))))
         (labels ((update (u what)
                    (α #'* (float 1/4)
                       (α #'+
                          (-> u (τ (i j) ((1+ i) j)) what)
                          (-> u (τ (i j) ((1- i) j)) what)
                          (-> u (τ (i j) (i (1+ j))) what)
                          (-> u (τ (i j) (i (1- j))) what)
                          (-> (α #'* (* h h) f) what)))))
           (loop repeat iterations do
             (setf u (fuse* u (update u r1) (update u r2)))
             (setf u (fuse* u (update u b1) (update u b2))))
           u)))
    (3 (let ((r1 (σ* u ((+ start 2) 2 (1- end)) ((+ start 2) 2 (1- end)) ((+ start 2) 2 (1- end))))
             (r2 (σ* u ((+ start 1) 2 (1- end)) ((+ start 1) 2 (1- end)) ((+ start 2) 2 (1- end))))
             (r3 (σ* u ((+ start 2) 2 (1- end)) ((+ start 1) 2 (1- end)) ((+ start 1) 2 (1- end))))
             (b1 (σ* u ((+ start 2) 2 (1- end)) ((+ start 1) 2 (1- end)) ((+ start 2) 2 (1- end))))
             (b2 (σ* u ((+ start 1) 2 (1- end)) ((+ start 2) 2 (1- end)) ((+ start 2) 2 (1- end))))
             (b3 (σ* u ((+ start 2) 2 (1- end)) ((+ start 2) 2 (1- end)) ((+ start 1) 2 (1- end)))))
         (labels ((update (u what)
                    (α #'* (float 1/6)
                       (α #'+
                          (-> u (τ (i j k) ((1+ i) j k)) what)
                          (-> u (τ (i j k) ((1- i) j k)) what)
                          (-> u (τ (i j k) (i (1+ j) k)) what)
                          (-> u (τ (i j k) (i (1- j) k)) what)
                          (-> u (τ (i j k) (i j (1+ k))) what)
                          (-> u (τ (i j k) (i j (1- k))) what)
                          (-> (α #'* (* h h) f) what)))))
           (loop repeat iterations do
             (setf u (fuse* u (update u r1) (update u r2) (update u r3)))
             (setf u (fuse* u (update u b1) (update u b2) (update u b3))))
           u)))))
