(in-package #:l-math)

(define-condition l-math-error (error)
  ((format-control :initarg :format-control
		   :initform "A general mathematical error has occured."
		   :reader l-math-error-format-control)
   (format-arguments :initarg :format-arguments
		     :initform nil
		     :reader l-math-error-format-arguments))
  (:report (lambda (condition stream)
	     (apply #'format
		    stream
		    (l-math-error-format-control condition)
		    (l-math-error-format-arguments condition)))))

(define-condition dimension-error (l-math-error)
  ((dim1 :initarg :dim1
	 :initform nil
	 :reader dimension-error-dim1)
   (dim2 :initarg :dim2
	 :initform nil
	 :reader dimension-error-dim2))
  (:report (lambda (condition stream)
	     (apply #'format stream
		    "The dimensions of the mathematical objects do not agree: ~a vs ~a"
		    (list
		     (dimension-error-dim1 condition)
		     (dimension-error-dim2 condition))))))

(define-condition operation-not-supported (error)
  ((operation-name :initarg :operation-name
		   :initform "<generic operation>"
		   :reader operation-not-suported-operation-name))
  (:report (lambda (condition stream)
	     (apply #'format stream
		    "Attempted to perform the unknown operation ~a "
		    (operation-not-suported-operation-name condition)))))