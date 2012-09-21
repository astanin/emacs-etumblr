;;; This module allows to authorize an Emacs app to use Tumblr API v2.
;;; It allows to post a simple text message.
;;;
;;; Usage:
;;;
;;;    1. Register your app, set callback to "http://localhost:12345/",
;;;       obtain OAuth Consumer Key and Secret:
;;;
;;;       http://www.tumblr.com/oauth/apps
;;;
;;;    2. Get user authorization:
;;;
;;;        (setq access-token
;;;           (etumblr-authorize-app "OAUTH-CONSUMER-KEY" "SECRET-KEY"))
;;;
;;;    3. Upon sucess, try to post a message:
;;;
;;;        (etumblr-post-text access-token "example.tumblr.com"
;;;              "Hello world!" "Sincerely yours,\n\n_Emacs_")
;;;
;;; Dependencies:
;;;
;;;    oauth.el by Peter Sanford to do the hard work
;;;    elnode.el by Nic Ferrier to run HTTP server and receive the callback
;;;
;;; Public domain

(require 'elnode)
(require 'oauth)

(defvar *etumblr-callback-port* 12345)
(defvar *etumblr-oauth-verifier* nil)
(defvar *etumblr-access-token* nil)

(defvar *etumblr-request-token-url* "http://www.tumblr.com/oauth/request_token")
(defvar *etumblr-access-token-url* "http://www.tumblr.com/oauth/access_token")
(defvar *etumblr-authorize-url* "http://www.tumblr.com/oauth/authorize")

(defun html-escape (str)
  (let* ((s1 (replace-regexp-in-string "&" "&amp;" str))
         (s2 (replace-regexp-in-string "<" "&lt;" s1))
         (res (replace-regexp-in-string ">" "&gt;" s2)))
    res))

(defun oauth-callback-handler (httpcon)
  "Upon successful callback, set *etumblr-oauth-verifier* variable."
  (let* ((oauth-token (elnode-http-param httpcon "oauth_token"))
         (oauth-verifier (elnode-http-param httpcon "oauth_verifier")))
    (flet ((http-response (title escaped-body)
                          (elnode-http-start
                           httpcon 200
                           '("Content-Type" . "text/html"))
                          (elnode-http-return
                           httpcon
                           (concat
                            "<!DOCTYPE html><html><head><title>"
                            (html-escape title)
                            "</title></head>"
                            "<body><h1>"
                            (html-escape title)
                            "</h1>"
                            escaped-body
                            "</body></html>"))))
      (setq *etumblr-oauth-verifier* oauth-verifier)
      (if oauth-verifier
          (http-response "Authorized"
                         (concat "<p>Verification code: <code>"
                                 (html-escape oauth-verifier)
                                 "</code></p>"
                                 "<p>You may close this page now.</p>"))
        (http-response "Access denied" "")))))

(defun start-handler (port)
  (elnode-start 'oauth-callback-handler
                :port port :host "localhost"))

(defun stop-handler (port)
  (elnode-stop port))

(defun oauth-authorize-app-with-cb
  (consumer-key consumer-secret request-url access-url authorize-url port)
  "Modified oauth-authorize-app with a callback handler at localhost.

  Upon success, set *etumblr-access-token*."
  (let ((auth-t) (auth-req) (unauth-t) (auth-url) (access-token)
        (unauth-req (oauth-sign-request-hmac-sha1
                     (oauth-make-request request-url consumer-key)
                     consumer-secret))
        (old-logging elnode-error-log-to-messages))
    (setq unauth-t (oauth-fetch-token unauth-req))
    (setq auth-url (format "%s?oauth_token=%s"
                           authorize-url (oauth-t-token unauth-t)))
    ;; start handler, visit auth-url
    (setq elnode-error-log-to-messages nil)
    (start-handler port)
    (if oauth-enable-browse-url (browse-url auth-url))
    (read-string (concat "Please authorize this application by visiting:\n"
                         auth-url
                         "\nPress ENTER when ready."))
    (stop-handler port)
    (setq elnode-error-log-to-messages old-logging)
    ;; proceed
    (if *etumblr-oauth-verifier*
        (progn
          (setq auth-req
                (oauth-sign-request-hmac-sha1
                 (oauth-make-request
                  (concat access-url "?oauth_verifier=" *etumblr-oauth-verifier*)
                  consumer-key unauth-t)
                 consumer-secret))
          (setq auth-t (oauth-fetch-token auth-req))
          (setq *etumblr-access-token*
                (make-oauth-access-token :consumer-key consumer-key
                                         :consumer-secret consumer-secret
                                         :auth-t auth-t))))))

(defun etumblr-authorize-app (consumer-key consumer-secret &optional port)
  "Run interactive OAuth authorization. Return keys and access token."
  (interactive "MConsumer key: \nMSecret key: \nNPort number: ")
  (let ((port (or port *etumblr-callback-port*)))
    (oauth-authorize-app-with-cb consumer-key
                                 consumer-secret
                                 *etumblr-request-token-url*
                                 *etumblr-access-token-url*
                                 *etumblr-authorize-url*
                                 port)))

(defun etumblr-post-text (access-token hostname title body)
  "Create a new text post in a Tumblr blog.

   Parameters:

   access-token    OAuth access token as obtained from etubmlr-authorize-app

   hostname        standard or custom blog hostname, e.g. example.tumblr.com
                   or tumblrblog.example.com

   title           post title

   body            post text in markdown format"
   ;;; TODO: extract status and/or JSON from the response,
   ;;; or, better, patch emacs-tumblr...
  (let ((posturl (concat "http://api.tumblr.com/v2/blog/" hostname "/post")))
    (oauth-post-url access-token posturl
                    `(("type"   . "text")
                      ("title"  . ,(html-escape title))
                      ("body"   . ,body)
                      ("format" . "markdown")))))

(provide 'etumblr)
