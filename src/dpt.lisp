(defpackage :knx-conn.dpt
  (:use :cl :knxobj :knxutil)
  (:nicknames :dpt)
  (:export #:dpt
           #:dpt-value-type
           #:dpt-value
           #:dpt-byte-len
           #:dpt1
           #:make-dpt1
           #:dpt9
           #:make-dpt9))

(in-package :knx-conn.dpt)

(defgeneric dpt-byte-len (dpt)
  (:documentation "Return the length of the DPT"))

(defgeneric dpt-value (dpt)
  (:documentation "Return the specific value of the DPT"))

(defstruct (dpt (:include knx-obj)
                (:conc-name dpt-)
                (:constructor nil))
  "A DPT is a data point type.
I.e. the value for switches, dimmers, temperature sensors, etc. are all encoded using DPTs. The DPTs are used to encode and decode the data for transmission over the KNX bus."
  (value-type (error "Required value-type") :type string))

;; ------------------------------
;; DPT1
;; ------------------------------

(defstruct (dpt1 (:include dpt)
                 (:constructor %make-dpt1))
  "
            +-7-+-6-+-5-+-4-+-3-+-2-+-1-+-0-+
Field Names |                             b |
Encoding    |                             B |
            +---+---+---+---+---+---+---+---+
Format:     1 bit (B<sub>1</sub>)
Range:      b = {0 = off, 1 = on}"
  (raw-value (error "Required value!") :type octet)
  (value (error "Required value!") :type (member :on :off)))

(defmethod dpt-byte-len ((dpt dpt1))
  1)

(defmethod dpt-value ((dpt dpt1))
  (dpt1-value dpt))

(defmethod to-byte-seq ((dpt dpt1))
  (vector (dpt1-raw-value dpt)))

(defun make-dpt1 (value-sym value)
  (ecase value-sym
    (:switch
        (%make-dpt1 :value-type "1.001"
                    :value value
                    :raw-value (ecase value
                                 (:on 1)
                                 (:off 0))))))

;; ------------------------------
;; DPT9
;; ------------------------------

(defstruct (dpt9 (:include dpt)
                 (:constructor %make-dpt9))
  "Data Point Type 9 for '2-Octet Float Value' (2 Octets)

            +-7-+-6-+-5-+-4-+-3-+-2-+-1-+-0-+-7-+-6-+-5-+-4-+-3-+-2-+-1-+-0-+
Field Names | (Float Value)                                                 |
Encoding    | M   E   E   E   E   M   M   M   M   M   M   M   M   M   M   M |
            +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
Format:     2 octets (F_16)
Encoding:   Float Value = (0.01 * M)*2(E)
            E = [0 .. 15]
            M = [-2048 .. 2047], two's complement notation"
  (raw-value (error "Required raw-value!") :type (vector octet 2))
  (value (error "Required value!") :type single-float))

(defmethod dpt-byte-len ((dpt dpt9))
  2)

(defmethod dpt-value ((dpt dpt9))
  (dpt9-value dpt))

(defmethod to-byte-seq ((dpt dpt9))
  (dpt9-raw-value dpt))

(defun %make-dpt9-temperature-raw-value (value)
  "9.001 Temperature (°C)
Range:      [-273 .. 670760.96]
Unit:       °C
Resolution: 0.01 °C"
  (declare (float value))
  (log:debug "Value for DPT9.001: ~a" value)
  (let* ((scaled-value (* 100 value))
         (exponent 0)
         (value-negative (minusp scaled-value)))
    (flet ((loop-scaled (pred-p)
             (do ((scaled-val scaled-value (/ scaled-val 2)))
                 ((funcall pred-p scaled-val)
                  scaled-val)
               (incf exponent))))
      (setf scaled-value
            (if value-negative
                (loop-scaled (lambda (val) (< val -2048.0)))
                (loop-scaled (lambda (val) (> val 2047.0)))))
      (log:debug "Exponents for '~a': ~a" value exponent)
      (log:debug "Scaled value for '~a': ~a" value scaled-value)

      (let ((mantissa (logand (round scaled-value) #x7ff)))
        (log:debug "Mantissa for '~a': ~a" value mantissa)
        (let* ((high-byte (if value-negative #x80 #x00))
               (high-byte (logior high-byte (ash exponent 3)))
               (high-byte (logior high-byte (ash mantissa -8))))
          (log:debug "High byte for '~a': ~a" value high-byte)

          (let ((low-byte (logand mantissa #xff)))
            (log:debug "Low byte for '~a': ~a" value low-byte)
            (vector high-byte low-byte)))))))

(defun make-dpt9 (value-sym value)
  "9.001 Temperature (°C)
`VALUE-SYM' can be `:temperature' for 9.001."
  (declare (float value))
  (ecase value-sym
    (:temperature
        (%make-dpt9 :value-type "9.001"
                    :raw-value (seq-to-array
                                (%make-dpt9-temperature-raw-value value)
                                :len 2)
                    :value value))))

