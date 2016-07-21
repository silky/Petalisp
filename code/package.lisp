;;; © 2016 Marco Heisig - licensed under AGPLv3, see the file COPYING

(in-package :cl-user)

(defpackage :petalisp
  (:use :cl :optima :alexandria)
  (:shadow #:equalp #:intersection)
  (:export
   #:α
   #:β
   #:repeat
   #:select
   #:fuse))
