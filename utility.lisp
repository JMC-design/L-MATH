(declaim (optimize (speed 0) (safety 3) (debug 3)))
(in-package #:l-math)

;;; L-MATH: a library for simple linear algebra.
;;; Copyright (C) 2009-2011 Rudolph Neeser
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;
;;; Additional permission under GNU GPL version 3 section 7
;;; 
;;; Linking this library statically or dynamically with other modules is
;;; making a combined work based on this library. Thus, the terms and
;;; conditions of the GNU General Public License cover the whole
;;; combination.
;;; 
;;; As a special exception, the copyright holders of this library give you
;;; permission to link this library with independent modules to produce an
;;; executable, regardless of the license terms of these independent
;;; modules, and to copy and distribute the resulting executable under
;;; terms of your choice, provided that you also meet, for each linked
;;; independent module, the terms and conditions of the license of that
;;; module. An independent module is a module which is not derived from or
;;; based on this library. If you modify this library, you may extend this
;;; exception to your version of the library, but you are not obligated to
;;; do so. If you do not wish to do so, delete this exception statement
;;; from your version.

;;;--------------------------------------------------------------------------
;;; Various utility functions, such as factorials and so on.
;;;--------------------------------------------------------------------------

(defun factorial (n)
  "Calculates the factorial of the integer, n. The factorial is the
  product of the sequence of integers 1, 2, 3, ..., n. n must not be a
  negative number. The factorial of n = 0 is defined to be 1."
  (declare (type integer n))
  (when (minusp n)
    (error 'l-math-error :format-control "Cannot calculate the factorial of a negative number."))
  (labels ((fact-accum (n accum)
	     (declare (type integer n accum))
	     (cond
	       ((<= n 1)
		accum)
	       (t
		(fact-accum (1- n) (* n accum))))))
    (fact-accum n 1)))

;;;--------------------------------------------------------------------------

(defun binomial-coefficient (n i)
  "Calculates the binomial coefficients. n and i must be non-negative."
  (declare (type integer n i))
  (when (or (minusp n)
	    (minusp i))
    (error 'l-math-error :format-control "The binomial coefficients only exist for non-negative n and i."))
  (cond
    ((cl:zerop i)
     1)
    ((cl:zerop n)
     0)
    ((> i n)
     0)
    (t 
     (/ (factorial n)
	(* (factorial i) (factorial (- n i)))))))

;;;--------------------------------------------------------------------------

(defun create-bernstein-polynomial (n i)
  "Returns a bernstein polynomial for n and i. This returned function
  takes one parameter."
  (declare (type integer n i))
  (when (or (minusp n)
	    (minusp i))
    (error 'l-math-error :format-control "n and i cannot be negative."))
  (cond
    ((and (zerop n)
	  (zerop i))
     (format t "Both zero~%")
     #'(lambda (t-val)
	 (declare (ignore t-val))
	 1))
    ((or (minusp i)
	 (> i n))
     (format t "out of range.~%")
     #'(lambda (t-val)
	 (declare (ignore t-val))
	 0))
    (t
     (let ((coefficient (binomial-coefficient n i)))
       #'(lambda (t-val)
	   (* coefficient
	      (expt t-val i)
	      (expt (- 1 t-val) (- n i))))))))

(defun evaluate-bernstein-polynomial (n i t-val)
  "Evaluates the bernstein polygnomial for n and i at t-val. If this
polynomial will be used multiple times, it might be more efficient to
create it using CREATE-BERNSTEIN-POLYNOMIAL."
  (funcall (create-bernstein-polynomial n i) t-val))


;;;--------------------------------------------------------------------------

(defclass b-spline-knots ()
  ((knots :initform nil
	  :initarg :knots
	  :type (or null (simple-array double-float))
	  :accessor knots
	  :documentation "An ascending collection of knots, stored with
	  repetition.")
   (multiplicity :initform nil
		 :initarg :multiplicity
		 :type (or null (simple-array fixnum))
		 :accessor multiplicity
		 :documentation "The multiplicity of the above knots."))
  (:documentation "Some docs. You will likely find it more convenient
  to construct instance of this class using MAKE-KNOTS."))

(defmethod initialize-instance :after ((knots b-spline-knots) &key)
  (unless (= (length (knots knots))
	     (length (multiplicity knots)))
    (error 'l-math-error :format-control "There are a different number of knots to specified multiplicity.")))

(defun make-knots (knots multiplicity)
  (declare (type list knots multiplicity))
  (make-instance 'b-spline-knots
		 :knots  (make-array (length knots) :element-type 'double-float
				     :initial-contents (mapcar #'(lambda (knot)
								   (coerce knot 'double-float))
							       knots))
		 :multiplicity (make-array (length multiplicity) :element-type 'fixnum
					   :initial-contents (mapcar #'(lambda (multi)
									 (coerce multi 'fixnum))
								     multiplicity))))

(defgeneric knot-count (knot-data)
  (:documentation "Returns the number of knots in the data, taking in
  to account multiplicity.")
  (:method ((knot-data b-spline-knots))
    (with-accessors ((multiplicity multiplicity)) knot-data
      (loop
	 for m across multiplicity
	 sum m))))

(defgeneric get-ith-knot (knot-data i)
  (:documentation "Returns the ith knot, taking in to account
  multiplicity.")
  (:method ((knot-data b-spline-knots) (i integer))
    (when (minusp i)
      (error 'l-math-error :format-control "The knot index may not be negative."))
    (with-accessors ((knots knots)
		     (multiplicity multiplicity)) knot-data
      (when (>= i (knot-count knot-data))
	(error 'l-math-error :format-control "The index is larger than the number of knots."))
      (loop
	 for index from 0 below (length multiplicity)
	 for m across multiplicity
	 sum m into count
	 while (<= count i)
	 finally (return index)))))
	   
  

(defgeneric find-knot-index (knot-data value)
  (:documentation "Given knot and multiplicity data, this returns the
  index in the knot array.")
  (:method ((knot-data b-spline-knots) (value real))
    (with-accessors ((knots knots)) knot-data
      (when (minusp value)
	(error 'l-math-error :format-control "Knot values may not be negative."))
      (when (> value (aref knots (1- (length knots))))
	(error 'l-math-error :format-control "This knot value is larger than the largest known know."))
      (labels ((find-array (knot-array value start end)
		 (declare (type (simple-array double-float) knot-array)
			  (type real value)
			  (type fixnum start end))
		 (let ((middle (floor (/ (+ start end) 2))))
		   (cond
		     ((and (<= (aref knot-array middle) value)
			   (> (aref knot-array (1+ middle)) value))
		      middle)
		     ((< (aref knot-array middle) value)
		      (find-array knot-array value middle end))
		     (t
		      (find-array knot-array value start middle))))))
	(find-array knots value 0 (1- (length knots)))))))
	       

(defun b-spline-basis (knot-data degree family parameter)
  (declare (type b-spline-knots knot-data)
	   (type fixnum degree)
	   (type number parameter))
  (when (minusp degree)
    (error 'l-math-error :format-control "The degree of a b-spline may not be negative."))
  (let ((current (get-ith-knot knot-data family))
	(before (if (not (minusp (1- family)))
		    (get-ith-knot knot-data (1- family))
		    nil))
	(nth-after (if (<= (knot-count knot-data) (+ family degree))
		       nil
		       (get-ith-knot knot-data (+ family degree))))
	(nth-after-1 (if (or (<= degree 0)
			     (<= (knot-count knot-data) (+ family (1- degree))))
			 nil
			 (get-ith-knot knot-data (+ family (1- degree))))))
    (cond
      ((zerop degree)
       (if (and (not (null before))
	        (<= before parameter)
		(< parameter current))
	   1
	   0))
      (t
       (+ (cond
	    ((or (null before)
		 (null nth-after-1)
		 (equivalent 0 (- nth-after-1 before)))
	     (format t "zero first term.~%")
	     0)				; Need to see if this term disappears.
	    (t
	     (* (/ (- parameter before)
		   (- nth-after-1 before))
		(b-spline-basis knot-data (1- degree) family parameter))))
	  (cond
	    ((or (null nth-after)
		 (equivalent 0 (- nth-after current)))
	     (format t "Zero second term.~%")
	     0)
	    (t
	     (* (/ (- nth-after parameter)
		   (- nth-after current))
		(b-spline-basis knot-data (1- degree) (1+ family) parameter)))))))))


;; (defun b-spline-basis (knot-data degree family parameter)
;;   (declare (type b-spline-knots knot-data)
;; 	   (type fixnum degree)
;; 	   (type number parameter))
;;   (when (minusp degree)
;;     (error 'l-math-error :format-control "The degree of a b-spline may not be negative."))
;;   (let ((current (get-ith-knot knot-data family))
;; 	(before (when (not (zerop family))
;; 		  (get-ith-knot knot-data (1- family))))
;; 	(nth-after (get-ith-knot knot-data (+ family degree)))
;; 	(nth-after-1 (get-ith-knot knot-data (+ family (1- degree)))))
;;     (cond
;;       ((zerop degree)
;;        (format t "par ~A; cur ~A; bef ~A~%" parameter current before)
;;        (format t "Zero! ~A~%" (list (not (null before))
;; 				    (<= before parameter)
;; 				    (< parameter current)))
;;        (if (and (not (null before))
;; 	        (<= before parameter)
;; 		(< parameter current))
;; 	   1
;; 	   0))
;;       (t
;;        (+ (if (and before (not (equivalent 0 (- nth-after-1 before))))
;; 	      (* (/ (- parameter before)
;; 		    (- nth-after-1 before))
;; 		 (b-spline-basis knot-data (1- degree) family parameter))
;; 	      0)
;; 	  (if (not (equivalent 0 (- nth-after current)))
;; 	      (* (/ (- nth-after parameter)
;; 		    (- nth-after current))
;; 		 (b-spline-basis knot-data (1- degree) (1+ family) parameter))
;; 	      0))))))


(defun test-b-spline (knots points parameter)
  (loop
     for p in points
     for i from 0
     for result = (* p (b-spline-basis knots 3 i parameter)) then (+ result (* p (b-spline-basis knots 3 i parameter)))
     do (format t "at ~A with result ~A~%" i (* p (b-spline-basis knots 3 i parameter)))
     finally (return result)))