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

;;;--------------------------------------------------------------------
;;; A base class for all spline implementations
;;;--------------------------------------------------------------------

(defclass spline ()
  ()
  (:documentation "A base class for all spline and parametric curve
  implementations."))

;;;--------------------------------------------------------------------

(defgeneric evaluate (spline parameter)
  (:documentation "Evaluate the given spline at the given parameter
  value. Returns a point on that spline."))

(defgeneric spline-geometry (spline)
  (:documentation "Returns the geometry of the associated
  spline. These are the end points, tangents, and so on, of the
  various splines."))

(defgeneric set-spline-geometry (spline geometry)
  (:documentation "Set the control geometry (end points, tangents,
  etc.) of the given spline."))

(defsetf spline-geometry set-spline-geometry)

(defgeneric maximum-parameter (spline)
  (:documentation "Returns the maximum value that the spline parameter
  may take."))

(defgeneric minimum-parameter (spline)
  (:documentation "Returns the minimum value that the spline parameter
  may take."))

;;;--------------------------------------------------------------------

(defclass matrix-spline (spline)
  ((basis-matrix :initarg :basis-matrix
		 :accessor basis-matrix
		 :documentation "Defines the behaviour of the
		 spline. For possible bases to use, see
		 MAKE-HERMITE-BASIS-MATRIX, MAKE-BEZIER-BASIS-MATRIX,
		 and MAKE-UNIFORM-NONRATIONAL-BSPLINE-BASIS-MATRIX")
   (geometry :initform nil
	     :type (or null simple-array)
	     :documentation "An array storing the various geometry
	     matrices that make up the spline."))
  (:documentation "Used to represent splines that are defined by basis
  matrices."))

(defmethod evaluate ((spline matrix-spline) (parameter real))
  "Evaluates the given spline at the parameter."
  (multiple-value-bind (geometry-index t-val)
      (floor parameter)
    (with-slots (geometry) spline
      (unless geometry
	(error 'spline-geometry-error :format-control "The curve does not have any geometry defined. There is nothing to evaluate."))
      ;; Because of the use of floor above, we will never have a t-val
      ;; of 1.0, which we do want for the very last geometry
      ;; matrix. This ensure we get it.
      (when (and (= geometry-index (cl:length geometry))
		 (= t-val 0))
	(decf geometry-index)
	(setf t-val 1))
      ;; Check that we do not overshoot the geometry.
      (when (minusp geometry-index)
      	(error 'spline-geometry-error :format-control "The parameter may not be negative."))
      (when (>= geometry-index (cl:length geometry))
	(format t "~A" geometry-index)
      	(error 'spline-geometry-error
	       :format-control "The parameter (~A) is too large for the geometry defining the spline (max possible parameter ~A)."
	       :format-arguments (list parameter (maximum-parameter spline))))
      (let ((t-vec (lm:vector (expt t-val 3) (expt t-val 2) t-val 1)))
      	(lm:* t-vec (basis-matrix spline) (aref (slot-value spline 'geometry) geometry-index))))))

(defmethod maximum-parameter ((spline matrix-spline))
  (length (slot-value spline 'geometry)))

(defmethod minimum-parameter ((spline matrix-spline))
  (declare (ignore spline))
  0)

(defgeneric coefficient-matrix (curve)
  (:documentation "Returns a list of coefficient matrices for the
  polynomials that control the curve along each segment. The first
  column of each matrix contains the coefficients for the polynomial
  calculating the x coefficients (row 1 is the cubic coefficient, row
  2 the quadratic coefficient, row 3 the linear coefficient, and row 4
  the constant). Column 2 does the same for the y polynomial
  coefficients, and column 3 for the z coefficients.")
  (:method ((spline matrix-spline))
    (with-accessors ((basis basis-matrix)) spline
      (labels ((make-coefficients (geometry)
		 (let ((x (* basis (lm:vector (matrix-elt geometry 0 0)
					      (matrix-elt geometry 1 0)
					      (matrix-elt geometry 2 0)
					      (matrix-elt geometry 3 0))))
		       (y (* basis (lm:vector (matrix-elt geometry 0 1)
					      (matrix-elt geometry 1 1)
					      (matrix-elt geometry 2 1)
					      (matrix-elt geometry 3 1))))
		       (z (* basis (lm:vector (matrix-elt geometry 0 2)
					      (matrix-elt geometry 1 2)
					      (matrix-elt geometry 2 2)
					      (matrix-elt geometry 3 2)))))
		   (make-matrix 4 3 :initial-elements (list (elt x 0) (elt y 0) (elt z 0)
							    (elt x 1) (elt y 1) (elt z 1)
							    (elt x 2) (elt y 2) (elt z 2)
							    (elt x 3) (elt y 3) (elt z 3))))))
	(loop
	   for geometry across (slot-value spline 'geometry)
	   collecting (make-coefficients geometry))))))

;;;--------------------------------------------------------------------
;;; a common geometry matrix form: sharing the last data point between
;;; geometry matrices.


(defclass last-shared-spline (matrix-spline)
  ()
  (:documentation "This class is for those curves / splines who set up
their geometry matrices by repeating the last element in a set of
four, such as the hermite and bézier curves."))

(defmethod set-spline-geometry ((spline last-shared-spline) (list list))
  "Sets the control geometry of the hermite curve and bézier
  curves.

  For hermite curves, this list should contain at least 4
  elements, and should be laid out in the following manner, where Pn
  represents the nth point, and a(Pn) represents the tangent leading
  away from that point, and b(Pn) represents the tangent leading
  towards that point.

  P1 a(P1) b(P2) P2 a(P2) b(P3) P3 a(P3) ... b(Pn-1) Pn-1 a(Pn-1) b(Pn) Pn

  For bézier curves, this should be a sequence of control points:

  P1 P2 P3 P4 P5 ... Pn

  Both the points and the tangents should be 3-vectors.
"

  ;; Some basic error checking.
  (let ((length (length list)))
    (when (< length 4)
      (error 'spline-geometry-error :format-control "There must be at least 4 geometry points to define a curve."))
    (when (/= (mod (- length 4) 3) 0)
      (error 'spline-geometry-error :format-control
	     "An incorrect number of geometry points has been given.
Ensure that there are an appropriate number of tangent vectors to
geometry points, or enought points."))

    (let* ((num-segments (1+ (/ (- length 4) 3)))
	   (array (make-array num-segments)))
      (labels ((create-array (data index)
		 (let ((matrix (make-matrix 4 3)))
		   (loop
		      for i from 0 below 4
		      for p = (nth i data) then (nth i data)
		      do (test-dimensions p 3)
		      do (setf (matrix-elt matrix i 0) (x p)
			       (matrix-elt matrix i 1) (y p)
			       (matrix-elt matrix i 2) (z p)))
		   (setf (aref array index) matrix))
		 (when (< (1+ index) num-segments)
		   (create-array (cdddr data) (1+ index)))))
	(create-array list 0))
      (setf (slot-value spline 'geometry) array)))
  list)

(defmethod spline-geometry ((spline last-shared-spline))
  "Returns a list of the geometry that made up the spline."
  (with-slots (geometry) spline
    (let ((first-matrix (aref geometry 0)))
      (append (list (lm:vector (matrix-elt first-matrix 0 0)
			       (matrix-elt first-matrix 0 1)
			       (matrix-elt first-matrix 0 2))
		    (lm:vector (matrix-elt first-matrix 1 0)
			       (matrix-elt first-matrix 1 1)
			       (matrix-elt first-matrix 1 2))
		    (lm:vector (matrix-elt first-matrix 2 0)
			       (matrix-elt first-matrix 2 1)
			       (matrix-elt first-matrix 2 2))
		    (lm:vector (matrix-elt first-matrix 3 0)
			       (matrix-elt first-matrix 3 1)
			       (matrix-elt first-matrix 3 2)))
	      (loop
		 for i from 1 below (length geometry)
		 appending (list (lm:vector (matrix-elt (aref geometry i) 1 0)
					    (matrix-elt (aref geometry i) 1 1)
					    (matrix-elt (aref geometry i) 1 2))
				 (lm:vector (matrix-elt (aref geometry i) 2 0)
					    (matrix-elt (aref geometry i) 2 1)
					    (matrix-elt (aref geometry i) 2 2))
				 (lm:vector (matrix-elt (aref geometry i) 3 0)
					    (matrix-elt (aref geometry i) 3 1)
					    (matrix-elt (aref geometry i) 3 2))))))))
		   
		    

;;;--------------------------------------------------------------------
;;; Three shared.

(defclass three-shared-spline (matrix-spline)
  ()
  (:documentation "Represents those splines for which the last three
  geometry points are always shared with a new point to construct the
  spline. These are splines such as the b-splines and catmull-rom
  splines."))

(defmethod set-spline-geometry ((spline three-shared-spline) (list list))
  "A list of points making up the spline geometry, in order of occurance."
  (let ((length (length list)))
    (when (< length 4)
      (error 'spline-geometry-error :format-control "There must be at least 4 geometry points to define a curve."))
    (let ((array (make-array (1+ (- (length list) 4)))))
      (labels ((create-array (data index)
		 (when (< index (length array))
		   (let ((matrix (make-matrix 4 3)))
		     (loop
			for i from 0 below 4
			for p = (nth i data) then (nth i data)
			do (test-dimensions p 3)
			do (setf (matrix-elt matrix i 0) (x p)
				 (matrix-elt matrix i 1) (y p)
				 (matrix-elt matrix i 2) (z p)))
		     (setf (aref array index) matrix))
		   (create-array (rest data) (1+ index)))))
	(create-array list 0)
	(setf (slot-value spline 'geometry) array))))
  list)

(defmethod spline-geometry ((spline three-shared-spline))
  "Returns the list of geometry making up the spline."
  (with-slots (geometry) spline
    (let ((first-matrix (aref geometry 0)))
      (append (list (lm:vector (matrix-elt first-matrix 0 0)
			       (matrix-elt first-matrix 0 1)
			       (matrix-elt first-matrix 0 2))
		    (lm:vector (matrix-elt first-matrix 1 0)
			       (matrix-elt first-matrix 1 1)
			       (matrix-elt first-matrix 1 2))
		    (lm:vector (matrix-elt first-matrix 2 0)
			       (matrix-elt first-matrix 2 1)
			       (matrix-elt first-matrix 2 2))
		    (lm:vector (matrix-elt first-matrix 3 0)
			       (matrix-elt first-matrix 3 1)
			       (matrix-elt first-matrix 3 2)))
	      (loop
		 for i from 1 below (length geometry)
		 collect (lm:vector (matrix-elt (aref geometry i) 3 0)
				    (matrix-elt (aref geometry i) 3 1)
				    (matrix-elt (aref geometry i) 3 2)))))))

;;;--------------------------------------------------------------------
;;; Hermite curves

(defclass hermite-curve (last-shared-spline)
  ()
  (:default-initargs :basis-matrix (make-hermite-basis-matrix))
  (:documentation "Represents a hermite curve in 3-space."))

;;;--------------------------------------------------------------------
;;; Bézier curves

(defclass cubic-bezier-curve (last-shared-spline)
  ()
  (:default-initargs :basis-matrix (make-bezier-basis-matrix))
  (:documentation "Represents a cubic bézier curve in 3-space."))

;;;--------------------------------------------------------------------
;;; Uniform, non-rational b-splines

(defclass unrbs-spline (three-shared-spline)
  ()
  (:default-initargs :basis-matrix (make-uniform-nonrational-bspline-basis-matrix))
  (:documentation "A uniform, non-rational b-spline in 3-space."))

;;;--------------------------------------------------------------------
;;; Catmul-rom splines

(defclass catmull-rom-spline (three-shared-spline)
  ()
  (:default-initargs :basis-matrix (make-catmull-rom-basis-matrix))
  (:documentation "The interpolating catmull-rom spline in 3-space. This spline
  passes through all of its control points. It is also called the
  Overhauser spine."))

;;;--------------------------------------------------------------------
;;;--------------------------------------------------------------------

(defclass bezier-curve (spline)
  ((degree :type integer
	   :accessor bezier-curve-degree
	   :documentation "The degree of the curve. The default is to be cubic.")
   (bernstein-polynomials :initform nil
			  :type list
			  :reader bernstein-polynomials
			  :documentation "A cached list of
			  berstein-polynomials, used in the
			  calculation of the curve.")
   (spline-geometry :initform nil
		    :initarg :spline-geometry
		    :documentation "A list of points defining the
		    curve. For a cubic curve, that is 4 points. For a
		    curve of degree n, there will be n+1 points."))
  (:documentation "A general bezier curve class, which can be of any
  degree (unlike CUBIC-BEZIER-CURVE, which is always cubic). Note that
  this is a single curve, and not a piecewise spline. If you want a
  piecewise generalisation of this, use the B-SPLINE class."))

(defmethod initialize-instance :after ((spline bezier-curve) &key (degree 3))
  (setf (bezier-curve-degree spline) degree))

(defmethod maximum-parameter ((spline bezier-curve))
  (declare (ignore spline))
  1)

(defmethod minimum-parameter ((spline bezier-curve))
  (declare (ignore spline))
  0)
			      

(defmethod spline-geometry ((spline bezier-curve))
  (slot-value spline 'spline-geometry))

(defmethod set-spline-geometry ((spline bezier-curve) (geometry list))
  "A list of points defining the bézier curve's geometry. For a curve
  of degree n, there should be n+1 points."
  (setf (slot-value spline 'spline-geometry) geometry))

(defmethod (setf bezier-curve-degree) :after ((degree integer) (spline bezier-curve))
  (when (not (plusp degree))
    (error 'l-math-error :format-control "The degree of a bézier curve must be positive."))
  (setf (slot-value spline 'bernstein-polynomials)
	(loop
	   for i from 0 upto degree
	   collect (create-bernstein-polynomial degree i))))

(defmethod evaluate ((spline bezier-curve) (t-val real))
  "Evaluates the given bezier curve at the given parameter value."
  (loop
     for p in (spline-geometry spline)
     for bern in (bernstein-polynomials spline)
     for result = (* p (funcall bern t-val)) then (+ result (* p (funcall bern t-val)))
     finally (return result)))

;;;--------------------------------------------------------------------
;;;--------------------------------------------------------------------

(defclass b-spline (spline)
  ((points :initform nil
	   :type list
	   :initarg :points
	   :accessor b-spline-points
	   :documentation "A list of points used defining the b-spline polygon.")
   (knots :initform nil
	  :type (or null b-spline-knots)
	  :initarg :knots
	  :accessor b-spline-knots
	  :documentation "A structure detailing the spline's knots.")
   (degree :initform 3
	   :type integer
	   :initarg :degree
	   :accessor b-spline-degree
	   :documentation "The degree of the b-spline. This defaults to cubic."))
  (:documentation "A non-uniform b-spline implementation. It has much
  code to speed up the uniform quadratic and cubic cases, however. But
  it supports arbitrary degree non-uniform b-splines in an arbtirary
  n-dimensional space.

  There are a number of options when constructing a b-spline. The
  simplest is when constructing a uniform b-spline, like so:

  (make-instance 'lm:b-spline :degree 3 :points *list-of-points* :uniform t)

  A non-uniform parameterisation that attempts to equalise the
  distance travelled over parameter sections is chord length parameterisation:
  (make-instance 'lm:b-spline :degree 3 :points *list-of-points* :chord-length t)

  Another non-uniform parameterisation (the prefered parametrisation)
  is centripetal parametrisation, which preserves ratios of square
  roots of distances between points of the control geometry:
  (make-instance 'lm:b-spline :degree 3 :points *list-of-points* :centripetal t)

  Knots may be specified with the :knots argument, and should be
  constructed using lm:MAKE-KNOTS."))

(defmethod initialize-instance :after ((spline b-spline) &key uniform chord-length centripetal)
  "UNIFORM: if true, will automatically create a set of uniform knots,
  based on the b-spline's degree and number of points in the b-spline
  polygon."
  (with-accessors ((points b-spline-points)
		   (degree b-spline-degree)) spline
    (let ((num-knots (number-needed-knots (length points) degree)))
      (when uniform
	(setf (b-spline-knots spline)
	      (make-knots (loop
			     repeat num-knots
			     for i from (- degree)
			     collect i)
			  :add-phantoms nil)))
      (when chord-length
	(setf (b-spline-knots spline)
	      (make-knots (chord-length-parameterisation points degree))))
      (when centripetal
	(setf (b-spline-knots spline)
	      (make-knots (centripetal-parameterisation points degree))))
      (when (and uniform chord-length centripetal)
	(error 'l-math-error
	       :format-control "Multiple different methods have been requested to produce knots."))
      (when (null (b-spline-knots spline))
	(error 'l-math-error
	       :format-control "No knots have been provided, or requested to be generated (eg, see :uniform keyword)"))
      (when (< (knot-count (b-spline-knots spline))
	       num-knots)
	(error 'l-math-error :format-control "This spline requires at least ~A knots and only has ~A."
	       :format-arguments (list num-knots (knot-count (b-spline-knots spline))))))))

(defmethod minimum-parameter ((spline b-spline))
    (low-parameter (b-spline-knots spline) (b-spline-degree spline)))

(defmethod maximum-parameter ((spline b-spline))
    (high-parameter (b-spline-knots spline) (b-spline-degree spline)))


(defmethod all-knots ((spline b-spline))
  "Returns a list of all the knots (repeated if necessary for
multiplicity) of the b-spline"
  (all-knots (b-spline-knots spline)))

(defgeneric domain-knots (spline)
  (:documentation "Returns a list of the domain knots of the
  spline (the knots over which the spline is defined). These are
  repeated for multiplicities.")
  (:method ((spline b-spline))
    (with-accessors ((degree b-spline-degree)) spline
      (nbutlast (nthcdr degree (all-knots spline)) degree))))

(defmethod print-object ((spline b-spline) stream)
  (print-unreadable-object (spline stream :type t :identity t)
    (format stream "from ~A to ~A over [~A, ~A]"
	    (evaluate spline (minimum-parameter spline))
	    (evaluate spline (maximum-parameter spline))
	    (minimum-parameter spline)
	    (maximum-parameter spline))))

(defmethod spline-geometry ((spline b-spline))
  (b-spline-points spline))

(defmethod get-ith-knot ((spline b-spline) (i integer) &optional (offset (b-spline-degree spline)))
  (get-ith-knot (b-spline-knots spline) i offset))

(defmethod set-spline-geometry ((spline b-spline) (geometry list))
  "A list of points defining the spline's b-spline polygon."
  (setf (b-spline-points spline) geometry))

(defmethod evaluate ((spline b-spline) (parameter number))
  (with-accessors ((knots b-spline-knots)
		   (degree b-spline-degree)
		   (points b-spline-points)) spline
    (unless (and (<= parameter (maximum-parameter spline))
    		 (>= parameter (minimum-parameter spline)))
      (error 'l-math-error :format-control "The given parameter (~A) should lay between ~A and ~A."
    	     :format-arguments (list parameter (minimum-parameter spline) (maximum-parameter spline))))
    (multiple-value-bind (family index)
	(find-starting-knot-index knots degree parameter)
      ;; We only want to make use of the least number of points that
      ;; affect the spline.  And so we calculate the "family" of the
      ;; b-spline bases that we want to use, while the index tells us
      ;; which spline segment we are calculating (which lets us know
      ;; which points we want to use.
      (loop
	 for p in (nthcdr (1- index) points)
	 for i from family to (+ family degree)
	 for fi from 0
	 for result = (* p (b-spline-basis knots degree i parameter :fast-spline-index fi)) then (+ result (* p (b-spline-basis knots degree i parameter :fast-spline-index fi)))
	 finally (return result)))))
    
