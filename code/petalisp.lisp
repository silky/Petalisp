;;; © 2016-2017 Marco Heisig - licensed under AGPLv3, see the file COPYING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Petalisp Vocabulary - Classes

(in-package :petalisp)

(define-class index-space () ()
  (:documentation
   "An index space of dimension D is a set of D-tuples i1,...,iD."))

(define-class transformation (unary-funcallable-object) ()
  (:metaclass funcallable-standard-class)
  (:documentation
   "A transformation is an analytically tractable function from indices to
   indices."))

(define-class data-structure ()
  ((element-type :initform t)
   (predecessors :initform nil :type list))
  (:documentation
   "A data structure of dimension D is a mapping from indices i1,...,iD to
   values of type ELEMENT-TYPE."))

(define-class elaboration (data-structure)
  (data)
  (:documentation
   "An elaboration is a data structure whose values are stored directly in
   memory, or whose elements are in tho process of being stored directly in
   memory."))

(define-class application (data-structure)
  ((operator :type function))
  (:documentation
   "Let F be a referentially transparent Common Lisp function that accepts
   n arguments, and let A1...AN be data structures with index space Ω. The
   the application of f to A1...AN is a data structure that maps each index
   k ∈ Ω to (F (A1 k) ... (AN k))."))

(define-class reduction (data-structure)
  ((operator :type function))
  (:documentation
   "Let F be a referentially transparent Common Lisp function that accepts
   two arguments, and let A be a data structure of dimension n, i.e. a
   mapping from each element of the cartesian product of the spaces S1,
   ..., Sn to some values. Then the reduction of A by F is a data structure
   of dimension n-1 that maps each element k of S1 ⨯ ... ⨯ Sn-1 to the
   pairwise combination of the elements {a(i) | i ∈ k ⨯ Sn} by F in some
   arbitrary order."))

(define-class fusion (data-structure) ()
  (:documentation
   "Let A1...AN be strided arrays with equal dimension, each mapping from
   an index space Ωk to a set of values.  Furthermore, let the sets Ω1...ΩN
   be pairwise disjoint, and let Ωf = ∪ Ω1...Ωk be again a valid index
   space. Then the fusion of A1...AN is a data structure that maps each
   index i ∈ Ωf to the value of i of the unique strided array Ak whose
   index space contains i."))

(define-class reference (data-structure)
  ((transformation :type transformation))
  (:documentation
   "Let A be a strided array with domain ΩA, let ΩB be a strided array
   index space and let T be a transformation from ΩB to ΩA. Then the
   reference of A by ΩB and T is a strided array that maps each index tuple
   k \in ΩB to A(T(k))."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Petalisp Vocabulary - Generic Functions

(defgeneric application (f a1 &rest a2...aN)
  (:documentation
   "Return a (potentially optimized and simplified) data structure
   equivalent to an instance of class APPLICATION.")
  (:method :around ((f function) (a1 data-structure) &rest a2...aN)
    (let/de ((a1...aN (list* a1 a2...aN)))
      (check-arity f (length a1...aN))
      (assert (identical a1...aN :test #'equal? :key #'index-space)))
    (or (apply #'optimize-application f a1 a2...aN)
        (call-next-method))))

(defgeneric binary-product (object-1 object-2)
  (:documentation "The generic function invoked by PRODUCT.")
  (:method ((a number) (b number))
    (* a b)))

(defgeneric binary-sum (object-1 object-2)
  (:documentation "The generic function invoked by SUM.")
  (:method ((a number) (b number))
    (+ a b)))

(defgeneric composition (g f)
  (:documentation
   "Returns a funcallable object such that its application is equivalent to
   the application of f, followed by an application of g.")
  (:method ((g function) (f function))
    (alexandria:compose g f))
  (:method :before ((g transformation) (f transformation))
    (assert (= (input-dimension g) (output-dimension f)))))

(defgeneric depetalispify (object)
  (:documentation
   "If OBJECT is a Petalisp data structure, return an array with the
   dimension, element type and contents of OBJECT. Otherwise return
   OBJECT.")
  (:method ((object t)) object))

(defgeneric difference (space-1 space-2)
  (:documentation
   "Return a list of index spaces that denote exactly those indices of
   SPACE-1 that are not indices of SPACE-2.")
  (:method :before ((space-1 index-space) (space-2 index-space))
    (assert (= (dimension space-1) (dimension space-2)))))

(defgeneric dimension (object)
  (:documentation
   "Return the number of dimensions of OBJECT.")
  (:method ((object t)) 0)
  (:method ((object array)) (length (array-dimensions object)))
  (:method ((object data-structure)) (dimension (index-space object))))

(defgeneric enqueue (object)
  (:documentation
   "Instruct Petalisp to compute the elements of OBJECT
   asynchronously. Return NIL."))

(defgeneric equal? (a b)
  (:documentation
   "Two objects are EQUAL? if their use in Petalisp will always result in
  identical behavior.")
  (:method ((a t) (b t)) (eql a b))
  (:method ((a structure-object) (b structure-object)) (equalp a b)))

(defgeneric fusion (a1 &rest a2...aN)
  (:documentation
   "Return a (potentially optimized and simplified) data structure
   equivalent to an instance of class FUSION.")
  (:method :around ((a1 data-structure) &rest a2...aN)
    (let/de ((a1...aN (list* a1 a2...aN)))
      (assert (identical a1...aN :test #'= :key #'dimension))
      (or (apply #'optimize-fusion a1 a2...aN)
          (call-next-method)))))

(defgeneric index-space (object)
  (:documentation
   "Return the INDEX-SPACE of OBJECT, i.e. a data structure whose elements
are the indices of OBJECT.")
  (:method ((object index-space))
    object))

(defgeneric input-dimension (transformation)
  (:documentation
   "Return the number of dimensions that a data structure must have to be a
   valid argument for TRANSFORMATION.")
  (:method ((A matrix)) (matrix-n A)))

(defgeneric intersection (space-1 space-2)
  (:documentation
   "Return an index space containing all indices that occur both in SPACE-1
   and SPACE-2.")
  (:method :before ((space-1 index-space) (space-2 index-space))
    (assert (= (dimension space-1) (dimension space-2)))))

(defgeneric inverse (transformation)
  (:documentation
   "Return a transformation whose composition with the argument of this
function is the identity transformation."))

(defgeneric optimize-application (f a1 &rest a2...aN)
  (:documentation "Return an optimized data-structure, or NIL.")
  (:method-combination or)
  (:method or ((f function) (a1 data-structure) &rest a2...aN)
    (when (and (eq f #'identity) (null a2...aN)) a1)))

(defgeneric optimize-fusion (a1 &rest a2...aN)
  (:documentation "Return an optimized data-structure, or NIL.")
  (:method-combination or)
  (:method or ((a1 data-structure) &rest a2...aN)
    "One-argument fusions are equivalent to that argument."
    (unless a2...aN a1)))

(defgeneric optimize-reduction (f a)
  (:documentation "Return an optimized data-structure, or NIL.")
  (:method-combination or)
  (:method or ((f function) (a data-structure))
    (declare (ignore f a))
    nil))

(defgeneric optimize-reference (object space transformation)
  (:documentation "Return an optimized data-structure, or NIL.")
  (:method-combination or)
  (:method or ((object data-structure) (space index-space) (transformation transformation)) nil)
  (:method or ((object reference) (space index-space) (transformation transformation))
    "Fold consecutive references. This method is crucial for Petalisp, as
    it ensures there will never be two consecutive references."
    (reference (predecessor object)
               space
               (composition (transformation object) transformation)))
  (:method or ((object fusion) (space index-space) (transformation transformation))
    "Permit references to fusions that affect only a single predecessor of
    this fuison to skip the fusion entirely, potentially leading to further
    optimization."
    (if-let ((unique-predecessor (find space (predecessors object)
                                       :test #'subspace?
                                       :key #'index-space)))
      (reference unique-predecessor space transformation))))

(defgeneric output-dimension (transformation)
  (:documentation
   "Return the number of dimensions of data structures generated by
   TRANSFORMATION.")
  (:method ((A matrix)) (matrix-m A)))

(defgeneric petalispify (object)
  (:documentation
   "If OBJECT is a Lisp array, convert it to a Petalisp data structure with
   the same dimension, element type and contents. If OBJECT is already a
   Petalisp data structure, return OBJECT. Otherwise return a
   zero-dimensional Petalisp data structure with OBJECT as its sole
   element.")
  (:method ((object data-structure)) object)
  (:method ((object t))
    (petalispify
     (make-array '() :initial-element object
                     :element-type (type-of object)))))

(defmethod print-object ((object data-structure) stream)
  (print-unreadable-object (object stream :type t :identity t)
    (princ (index-space object) stream)))

(defgeneric reduction (f a)
  (:documentation
   "Return a (potentially optimized and simplified) data structure
   equivalent to an instance of class REDUCTION.")
  (:method :around ((f function) (a data-structure))
    (assert (< 0 (dimension a)))
    (check-arity f 2)
    (or (optimize-reduction f a)
        (call-next-method))))

(defgeneric reference (object space transformation)
  (:documentation
   "Return a (potentially optimized and simplified) data structure
   equivalent to an instance of class REFERENCE.")
  (:method :around ((object data-structure)
                    (space index-space)
                    (transformation transformation))
    (assert (and (= (dimension space) (input-dimension transformation))
                 #+nil
                 (subspace? (funcall transformation space)
                            (index-space object))))
    (or (optimize-reference object space transformation)
        (call-next-method))))

(defgeneric result-type (function &rest arguments)
  (:method ((function function) &rest arguments)
    (declare (ignore arguments))
    t))

(defgeneric shallow-copy (object)
  (:documentation
   "Return an object that is EQUAL? to OBJECT, but not EQ."))

(defgeneric size (object)
  (:method ((object t)) 1)
  (:method ((object array)) (array-total-size object))
  (:method ((object data-structure)) (size (index-space object))))

(defgeneric subspace? (space-1 space-2)
  (:documentation
   "Return true if every index in SPACE-1 occurs also in SPACE-2.")
  (:method ((space-1 t) (space-2 t))
    (equal? space-1 (intersection space-1 space-2))))

(defgeneric view (object)
  (:documentation
   "Present OBJECT graphically.")
  (:method ((object t)) (describe object)))

(defgeneric wait-for-completion (&rest objects)
  (:documentation
   "Return the computed value of OBJECTS."))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Petalisp Vocabulary - Non-generic Functions

(declaim (inline sum product))

(defun sum (object &rest more-objects)
  "Returns the sum of the given objects, as computed by BINARY-SUM."
  (if (null more-objects)
      object
      (reduce #'binary-sum more-objects :initial-value object)))

(defun product (object &rest more-objects)
  "Returns the product of the given objects, as computed by BINARY-PRODUCT."
  (if (null more-objects)
      object
      (reduce #'binary-product more-objects :initial-value object)))

(defun predecessor (object)
  "Return the unique predecessor of OBJECT."
  (ematch (predecessors object)
    ((list first) first)))

(defun subdivision (object &rest more-objects)
  "Return a list of disjoint objects. Each resulting object is a proper
subspace of one or more of the arguments and their fusion covers all
arguments."
  (flet ((shatter (dust object) ; dust is a list of disjoint objects
           (let ((object-w/o-dust (list object)))
             (nconc
              (loop for particle in dust do
                (setf object-w/o-dust
                      (loop for x in object-w/o-dust
                            append (difference x particle)))
                    append (difference particle object)
                    when (intersection particle object) collect it)
              object-w/o-dust))))
    (reduce #'shatter more-objects :initial-value (list object))))
