(in-package #:l-math)

;;;---------------------------------------------------------------------
;;; Vector operations
;;;---------------------------------------------------------------------

(defgeneric dot-product (lhs rhs)
  (:documentation "Calculates the dot product between two vectors.")
  (:method ((lhs vector) (rhs vector))
    (test-dimensions lhs rhs)
    (with-slots ((lhs-data data)) lhs
      (with-slots ((rhs-data data)) rhs
	(unless (= (cl:length lhs-data)
		   (cl:length rhs-data))
	  (error 'dimension-error :dim1 (cl:length lhs-data)
		 :dim2 (cl:length rhs-data)))
	(loop for l across lhs-data
	   for r across rhs-data
	   sum (* l r))))))

(declaim (inline cross-product))
(defgeneric cross-product (lhs rhs)
  (:documentation "Calculates the cross product between 3-vectors")
  (:method ((lhs vector) (rhs vector))
    (test-dimensions lhs rhs)
    (unless (= (length lhs) 3)
      (error 'l-math-error :format-control "Can only perform cross products on 3-vectors."))
    (vector (- (* (y lhs) (z rhs))
	       (* (z lhs) (y rhs)))
	    (- (* (z lhs) (x rhs))
	       (* (x lhs) (z rhs)))
	    (- (* (x lhs) (y rhs))
	       (* (y lhs) (x rhs))))))

(defgeneric euclidean-distance (lhs rhs)
  (:documentation "Calculates the Euclidean distance between two objects."))

(defmethod euclidean-distance ((lhs vector) (rhs vector))
  "Calculates the Euclidean distance between two vectors."
  (test-dimensions lhs rhs)
  (with-slots ((lhs-data data)) lhs
    (with-slots ((rhs-data data)) rhs
      (sqrt 
       (loop
	  for i across lhs-data
	  for j across rhs-data
	  sum (expt (- i j) 2))))))

;;;-------------------------------------------------------------------
;;; Operations on numbers
;;;-------------------------------------------------------------------

(defmethod euclidean-distance ((lhs number) (rhs number))
  "Calculates the Euclidean distance between two numbers."
  (abs (- lhs rhs)))

;;;-------------------------------------------------------------------