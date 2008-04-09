(in-package :png-read)

(defvar *adam7* #2A((1 6 4 6 2 6 4 6)
		    (7 7 7 7 7 7 7 7)
		    (5 6 5 6 5 6 5 6)
		    (7 7 7 7 7 7 7 7)
		    (3 6 4 6 3 6 4 6)
		    (7 7 7 7 7 7 7 7)
		    (5 6 5 6 5 6 5 6)
		    (7 7 7 7 7 7 7 7)))

(defun make-deinterlace-arrays (w h)
  (let ((leaves (make-array 7 :initial-element nil)))
    (dotimes (x w (map 'vector #'nreverse leaves))
      (dotimes (y h)
	(push (list x y) (aref leaves (1- (aref *adam7* (mod y 8) (mod x 8)))))))))

(defun get-height-passlist (pass-list)
  (let ((init-x (caar pass-list)))
    (iter (for d in pass-list)
	  (while (eql init-x (car d)))
	  (summing 1))))

(defun split-datastream (datastream bd colour-type sub-widths sub-heights)
  (let ((ctr 0))
   (iter (for w in sub-widths)
	 (for h in sub-heights)
	 (if (zerop w)
	     (vector)
	     (let ((step-ctr (ceiling (* w h bd (ecase colour-type
						  (:truecolor 3)
						  (:greyscale 1)
						  (:greyscale-alpha 2)
						  (:truecolor-alpha 4)
						  (:indexed-colour 1))) 8)))
	       (iter (until (zerop (mod step-ctr h)))
		     (incf step-ctr))
	       (let ((end-ctr (+ ctr h step-ctr)))
		 (collect (subseq datastream ctr end-ctr))
		 (setf ctr end-ctr)))))))

(defun decode-subimages (data png-state)
  (let ((w (width png-state))
	(h (height png-state)))
    (let ((sub-array (make-deinterlace-arrays w h)))
     (let ((sub-heights (map 'list #'get-height-passlist sub-array)))
       (let ((sub-widths (map 'list #'(lambda (lt wi)
					(if (zerop wi)
					    0
					    (/ (length lt) wi)))
			      sub-array sub-heights)))
	 (let ((datastreams (split-datastream data
					      (bit-depth png-state)
					      (colour-type png-state)
					      sub-widths
					      sub-heights)))
	   (values
	    (iter (for i from 0 below 7)
		  (for w in sub-widths)
		  (for h in sub-heights)
		  (until (zerop w))
		  (for datastream in datastreams)
		  (setf (width png-state) w
			(height png-state) h)
		  (decode-data (colour-type png-state) datastream png-state)
		  (collect (image-data png-state)))
	    sub-array sub-heights)))))))

(defun finish-deinterlace (colour-type w h sub-images sub-arrays sub-heights)
  (let ((image-final (make-array (ecase colour-type
				   (:greyscale (list w h))
				   (:truecolor (list w h 3))
				   (:indexed-colour (list w h 3))
				   (:greyscale-alpha (list w h 2))
				   (:truecolor-alpha (list w h 4))) :initial-element 0)))
    (iter (for sub-array in-vector sub-arrays)
	  (for sub-image in sub-images)
	  (for sub-height in sub-heights)
	  (iter (for (x y) in sub-array)
		(for i from 0)
		(ecase colour-type
		  (:greyscale (setf (aref image-final x y)
				    (aref sub-image (floor i sub-height) (mod i sub-height))))
		  ((:truecolor :indexed-colour) (iter (for k from 0 to 2)
						      (setf (aref image-final x y k)
							    (aref sub-image (floor i sub-height) (mod i sub-height) k))))
		  (:greyscale-alpha (iter (for k from 0 to 1)
				    (setf (aref image-final x y k)
					  (aref sub-image (floor i sub-height) (mod i sub-height) k))))
		  (:truecolor-alpha (iter (for k from 0 to 3)
				    (setf (aref image-final x y k)
					  (aref sub-image (floor i sub-height) (mod i sub-height) k)))))))
    image-final))

(defun decode-interlaced (data png-state)
  (let ((w (width png-state))
	(h (height png-state)))
   (multiple-value-bind (sub-images sub-arrays sub-heights) (decode-subimages data png-state)
     (setf (image-data png-state) (finish-deinterlace (colour-type png-state) w h sub-images sub-arrays sub-heights)
	   (width png-state) w
	   (height png-state) h))))