(defpackage :knx-conn.knx-connect-test
  (:use :cl :cl-mock :fiveam
   :knxutil :knxobj :descr-info :connect :tunnelling
        :crd :cemi :address :dib :dpt :knxc))

(in-package :knx-conn.knx-connect-test)

(def-suite knx-connect-tests
  :description "Tests for KNX connection handling"
  :in knx-conn.tests:test-suite)

(in-suite knx-connect-tests)

(log:config :debug)
(log:config '(sento) :warn)

(def-fixture env ()
  (unwind-protect
       (progn
         (knxc::%ensure-asys)
         (&body))
    (knxc::%shutdown-asys)))

;; --------------------------------------
;; description request/response
;; --------------------------------------

(setf knxc::*conn* 'foo)

(defparameter *descr-response-data*
  #(6 16 2 4 0 84 54 1 2 0 17 1 0 0 0 1 0 53 81 241 0 0 0 0 0 14 140 0 107 180 73
    80 32 73 110 116 101 114 102 97 99 101 32 78 49 52 56 0 0 0 0 0 0 0 0 0 0 0 0
    0 12 2 2 1 3 2 4 1 7 1 8 1 12 254 0 1 8 0 255 241 115 255 148 75 0 0 0 0 0 0
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))

(test retrieve-descr-info--receive-response--check-package
  (with-fixture env ()
    (with-mocks ()
      (answer usocket:socket-send t)
      (answer usocket:socket-receive *descr-response-data*)

      (let ((result-fut (retrieve-descr-info))
            (result))
        (miscutils:await-cond 0.5
          (not (eq :not-ready (future:fresult result-fut))))
        (setf result (future:fresult result-fut))
        (is (typep result 'knx-descr-response))
        ;; check knx-header
        (let ((header (package-header result)))
          (is (typep header 'knx-header))
          (is (eql knxobj::+knx-header-len+ (header-len header)))
          (is (eql descr-info::+knx-descr-response+ (header-type header)))
          (is (eql knxobj::+knx-netip-version+ (header-knxnetip-version header)))
          (is (eql (- 84 knxobj::+knx-header-len+) (header-body-len header))))
        ;; check dibs
        (is (typep (descr-response-device-hardware result)
                   'dib))
        (is (typep (descr-response-device-hardware result)
                   'dib-device-info))
        (is (typep (descr-response-supp-svc-families result)
                   'dib))
        (is (typep (descr-response-supp-svc-families result)
                   'dib-supp-svc-families))
        (is (typep (descr-response-other-dib-info result)
                   'dib-list))
        (is-false (endp (descr-response-other-dib-info result))))

      (is (eql 1 (length (invocations 'usocket:socket-send))))
      (is (eql 1 (length (invocations 'usocket:socket-receive)))))))

(test wait-for-response--with-timeout--stop-when-elapsed
  "Test that when a response is expected but it doesn't come within the
   specified timeout, the result is timeout condition."
  (with-fixture env ()
    (with-mocks ()
      (answer usocket:socket-send t)
      (answer usocket:socket-receive (progn
                                       (sleep 1)
                                       nil))

      (let ((knxc::*resp-wait-timeout-secs* 0.5)
            (result-fut (retrieve-descr-info)))
        (sleep 0.7)
        (is (eq :timeout (future:fresult result-fut)))))))

;; TODO:
;; - retrieve-knx-data with condition
;; - :receive with `(cons :handler-error foo)`


;; (defparameter *raw-descr-request*
;;   (make-array 14
;;               :element-type '(unsigned-byte 8)
;;               :initial-contents
;;               '(#x06 #x10
;;                 #x02 #x03
;;                 #x00 #x0e
;;                 ;; HPAI
;;                 #x08
;;                 #x01                ;; udp
;;                 #x00 #x00 #x00 #x00 ;; unbound address
;;                 #x00 #x00
;;                 )))

;; (test descr-request--compare-to-raw
;;   (is (equalp *raw-descr-request*
;;               (to-byte-seq
;;                (make-descr-request hpai:*hpai-unbound-addr*)))))

;; (defparameter *raw-descr-request-2*
;;   (make-array 14
;;               :element-type '(unsigned-byte 8)
;;               :initial-contents
;;               '(#x06 #x10
;;                 #x02 #x03
;;                 #x00 #x0e
;;                 ;; HPAI
;;                 #x08
;;                 #x01 ;; udp
;;                 192 168 50 100
;;                 195 180)))

;; (test descr-request--compare-to-raw-2
;;   (is (equalp *raw-descr-request-2*
;;               (to-byte-seq
;;                (make-descr-request
;;                 (hpai:make-hpai "192.168.50.100" 50100))))))

;; ;; --------------------------------------
;; ;; connect request/response
;; ;; --------------------------------------

;; (defparameter *connect-response-data-ok*
;;   #(6 16 2 6 0 20 78 0 8 1 0 0 0 0 0 0 4 4 238 255 0 0 0 0 0 0 0 0
;;     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;;     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;;     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))

;; (test connect--ok
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (answer usocket:socket-receive *connect-response-data-ok*)

;;     (let ((knxc::*channel-id* 0))
;;       (multiple-value-bind (response err)
;;           (establish-tunnel-connection)
;;         (is (eq nil err))
;;         (is (typep response 'knx-connect-response))
;;         ;; check knx-header
;;         (let ((header (package-header response)))
;;           (is (typep header 'knx-header)))
;;         ;; check connect response body
;;         (is (eql +connect-status-no-error+ (connect-response-status response)))
;;         (is (eql 78 (connect-response-channel-id response)))
;;         (is (equal (address-string-rep
;;                     (crd:crd-individual-address
;;                      (connect-response-crd response)))
;;                    "14.14.255")))
    
;;       (is (eql 1 (length (invocations 'usocket:socket-send))))
;;       (is (eql 1 (length (invocations 'usocket:socket-receive)))))))

;; (test connect--ok--sets-channel-id
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (answer usocket:socket-receive *connect-response-data-ok*)

;;     (let ((knxc::*channel-id* -1))
;;       (establish-tunnel-connection)
;;       (is (= knxc::*channel-id* 78)))
    
;;     (is (eql 1 (length (invocations 'usocket:socket-send))))
;;     (is (eql 1 (length (invocations 'usocket:socket-receive))))))

;; (defparameter *connect-response-data-err*
;;   #(6 16 2 6 0 20 78 34 8 1 0 0 0 0 0 0 4 4 238 255 0 0 0 0 0 0 0 0
;;     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;;     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
;;     0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
;;   "Connect response with error status")

;; (test connect--err
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (answer usocket:socket-receive *connect-response-data-err*)

;;     (multiple-value-bind (response err)
;;         (establish-tunnel-connection)
;;       (is (null response))
;;       (is (equal (format nil "~a" err)
;;                  (format nil
;;                          "Error condition: Connect response status, args: (~a)"
;;                          +connect-status-err-conn-type+))))
    
;;     (is (eql 1 (length (invocations 'usocket:socket-send))))
;;     (is (eql 1 (length (invocations 'usocket:socket-receive))))))

;; (test connect--err--does-not-set-channel-id
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (answer usocket:socket-receive *connect-response-data-err*)

;;     (let ((knxc::*channel-id* -1))
;;       (establish-tunnel-connection)
;;       (is (= knxc::*channel-id* -1)))
    
;;     (is (eql 1 (length (invocations 'usocket:socket-send))))
;;     (is (eql 1 (length (invocations 'usocket:socket-receive))))))

;; ;; --------------------------------------
;; ;; disconnect request/response
;; ;; --------------------------------------

;; (defparameter *disconnect-response-data-ok*
;;   #(6 16 2 10 0 8 0 0))

;; (test disconnect--ok
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (answer usocket:socket-receive *disconnect-response-data-ok*)

;;     (let ((knxc::*channel-id* 78))
;;       (multiple-value-bind (response err)
;;           (close-tunnel-connection)
;;         (is (eq nil err))
;;         (is (typep response 'knx-disconnect-response))))
      
;;     (is (eql 1 (length (invocations 'usocket:socket-send))))
;;     (is (eql 1 (length (invocations 'usocket:socket-receive))))))

;; (test disconnect--no-valid-channel-id
;;   (with-mocks ()
;;     (let ((knxc::*channel-id* nil))
;;       (handler-case
;;           (close-tunnel-connection)
;;         (simple-error (c)
;;           (is (equal (format nil "~a" c)
;;                      "No open connection!"))))
;;       (is (eql 0 (length (invocations 'usocket:socket-send))))
;;       (is (eql 0 (length (invocations 'usocket:socket-receive)))))))

;; ;; --------------------------------------
;; ;; tunneling request receival
;; ;; --------------------------------------

;; (defparameter *raw-tunnelling-request-data*
;;   #(6 16 4 32 0 23 4 76 0 0 41 0 188 208 19 14 4 10 3 0 128 12 104))

;; (test tunneling-receive-request--ok ()
;;   (with-mocks ()
;;     (answer usocket:socket-receive *raw-tunnelling-request-data*)

;;     (multiple-value-bind (request err)
;;         (receive-knx-data)
;;       (declare (ignore err))
;;       (is (not (null request)))
;;       (is (typep request 'knx-tunnelling-request)))
    
;;     (is (= 1 (length (invocations 'usocket:socket-receive))))))

;; ;; --------------------------------------
;; ;; tunneling request sending
;; ;; --------------------------------------

;; ;; reset this
;; (setf knxc::*channel-id* nil)
;; (setf knxc::*seq-counter* 0)

;; (test send-write-request--switch-on
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (let ((knxc::*channel-id* 78))
;;       (let ((req (send-write-request (make-group-address "0/4/10")
;;                                      (make-dpt1 :switch :on))))
;;         (is (= 78 (conn-header-channel-id
;;                    (tunnelling-request-conn-header req))))))
;;     (is (= 1 (length (invocations 'usocket:socket-send))))))

;; (test send-write-request--increment-seq-counter
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (let ((knxc::*channel-id* 78)
;;           (knxc::*seq-counter* 0))
;;       (let ((req (send-write-request (make-group-address "0/4/10")
;;                                      (make-dpt1 :switch :on))))
;;         (is (= 1 (conn-header-seq-counter
;;                   (tunnelling-request-conn-header req)))))
;;       (is (= 1 knxc::*seq-counter*)))
;;     (is (= 1 (length (invocations 'usocket:socket-send))))))

;; (test send-write-request--seq-counter-rollover
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (let ((knxc::*channel-id* 78)
;;           (knxc::*seq-counter* 254))
;;       (let ((req (send-write-request (make-group-address "0/4/10")
;;                                      (make-dpt1 :switch :on))))
;;         (is (= 0 (conn-header-seq-counter
;;                   (tunnelling-request-conn-header req)))))
;;       (is (= 0 knxc::*seq-counter*)))
;;     (is (= 1 (length (invocations 'usocket:socket-send))))))

;; (test send-read-request
;;   (with-mocks ()
;;     (answer usocket:socket-send t)
;;     (let ((knxc::*channel-id* 78)
;;           (knxc::*seq-counter* 79))
;;       (let ((req (send-read-request (make-group-address "0/4/10"))))
;;         (is (= 78 (conn-header-channel-id
;;                    (tunnelling-request-conn-header req))))
;;         (is (= 80 (conn-header-seq-counter
;;                    (tunnelling-request-conn-header req))))))
;;     (is (= 1 (length (invocations 'usocket:socket-send))))))

