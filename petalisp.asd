(defsystem :petalisp
  :description "Elegant High Performance Computing"
  :author "Marco Heisig <marco.heisig@fau.de>"
  :license "AGPLv3"
  :encoding :utf-8
  :class :package-inferred-system
  :depends-on
  ("petalisp/core/api"
   "agnostic-lizard"
   "alexandria"
   "bordeaux-threads"
   "lparallel"
   "trivia"
   "trivial-arguments")
  :in-order-to ((test-op (test-op :petalisp-test-suite))))

(register-system-packages "closer-mop" '(:closer-common-lisp))
(register-system-packages "petalisp/core/api" '(:petalisp))
