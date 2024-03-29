;;;  scala-plus.el -- A handful of helpers for scala-mode, some of which could be merged into scala-mode.el

;; Copyright (c) 2014 Tim Harper <timcharper@gmail.com>

;; Licensed under the same terms as Emacs.

;; Keywords: scala
;; Created: 8 May 2014
;; Author: Tim Harper <timcharper@gmail.com>
;; Version: 1

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Contains some helpers for scala-test


;;; scala-test helpers

(defcustom scala-plus:test-only-command "test-only" "The sbt command used to invoke test-only")

(defun scala-plus:sbt-test-only-cmd ()
  "Returns sbt command necessary to run the current test suite in an sbt repl"
  (interactive)
  (let* ((spec-name (scala-plus:guess-spec-name))
         (package-name (scala-plus:buffer-package-name))
         (outer-class (scala-plus:guess-outer-class))
         (cmd (if spec-name
                  (format "%s %s.%s -- -z %s -oF" scala-plus:test-only-command package-name outer-class spec-name)
                (format "%s %s.%s -- -oF" scala-plus:test-only-command package-name outer-class))))
    cmd))

(defun scala-plus:yank-sbt-test-only ()
  "Copies expression necessary to run the current test suite in an sbt repl"
  (interactive)
  (let* ((cmd (scala-plus:sbt-test-only-cmd)))
    (kill-new cmd)
    (message "Copied '%s' to the killring" cmd)))

(defun scala-plus:do-sbt-test-only ()
  "Runs test-only for test under point"
  (interactive)
  (sbt-command (scala-plus:sbt-test-only-cmd)))

(defvar scala-plus:imenu-generic-expression
  '(("Classes / Objects / Traits"   "^ *\\(\\(class\\|trait\\|object\\) +\\([a-zA-Z0-9_]+\\)\\)" 1)
    ("Defs"   "^ *\\(\\(private +\\|implicit +\\|protected +\\|\\)\\(def +\\([a-zA-Z0-9_]+\\)\\)\\)" 3)
    ;; funspec
    ("scalatest"   "^\\( *\\(describe\\|it\\) *( *\".+\" *)\\)" 1))
  "The imenu regex to parse an outline of the scala file")

(defun scala-plus:set-imenu-generic-expression ()
  (make-local-variable 'imenu-generic-expression)
  (make-local-variable 'imenu-create-index-function)
  (setq imenu-create-index-function 'imenu-default-create-index-function)
  (setq imenu-generic-expression scala-plus:imenu-generic-expression))


(defvar scala-test:main-file-format
  "%s/src/main/scala/%s%s.scala"
  "scala test format")

(defvar scala-test:test-file-format
  "%s/src/test/scala/%s%sSpec.scala"
  "scala test format")

(put 'scala-test:main-file-format 'safe-local-variable #'stringp)
(put 'scala-test:test-file-format 'safe-local-variable #'stringp)

;; (setq scala-test:main-file-format "%s/src/main/scala/%s%s.scala")
;; (setq scala-test:test-file-format "%s/src/test/scala/%sTest%s.scala")

;; (setq scala-test:main-file-format "%s/src/main/scala/%s%s.scala")
;; (setq scala-test:test-file-format "%s/src/test/scala/%s%sTest.scala")

(defun scala-test:format-to-regex (fmt)
  (format
   (replace-regexp-in-string "\\." "\\\\." fmt)
   "\\(.+\\)" "\\(.+/\\)?" "\\([^/]+\\)"))

(defun scala-test:toggle-spec-test ()
  "Toggle between test and spec"
  (interactive)
  (let* ((path buffer-file-name)

         (main-regex (scala-test:format-to-regex scala-test:main-file-format))
         (spec-regex (scala-test:format-to-regex scala-test:test-file-format))

         (other-path 
          (cond ((string-match spec-regex path)
                 (format scala-test:main-file-format
                         (match-string 1 path)
                         (match-string 2 path)
                         (match-string 3 path)))
                ((string-match main-regex path)
                 (format scala-test:test-file-format
                         (match-string 1 path)
                         (match-string 2 path)
                         (match-string 3 path))))))
    (message "%s" other-path)
    (find-file other-path)))


;;; general scala helpers

(defun scala-plus:buffer-package-name ()
  "Pulls the package name from the current file. If multiple packages declared before the point, then collect those too."
  (let ((point-start))
    (save-excursion
      (let* ((limit (point))
             (iter (lambda (collected)
                     (let ((package-segment
                            (and
                             (search-forward-regexp "^ *package *" limit t)
                             (let ((point-start (point)))
                               (search-forward-regexp "[^0-9A-Za-z._]")
                               (buffer-substring-no-properties point-start (- (point) 1))))))

                       (if package-segment
                           (funcall iter (append collected (list package-segment)))
                         collected)))))

        (goto-char 0)
        (mapconcat 'identity
                   (funcall iter nil)
                   ".")))))

(defun scala-plus:guess-wordspec-name ()
  "Returns outer class name containing the current point. Requires class name to be indented fully left."
  (let ((point-end))
    (condition-case nil
        (save-excursion
          (search-backward-regexp "^ *\".+\\b\\(should\\|in\\|when\\) ")
          (forward-sexp)
          (setq point-end (point))
          (backward-sexp)
          
          (buffer-substring-no-properties (point) point-end))
      (error nil))))

(defun scala-plus:guess-funspec-name ()
  "Returns outer class name containing the current point. Requires class name to be indented fully left."
  (let ((point-start))
    (condition-case nil
        (save-excursion
          (search-backward-regexp "^ *\\(it\\|test\\|describe\\)\\b[ \\t]*(\"")
          (search-forward-regexp "^ *\\(it\\|test\\|describe\\)\\b[ \\t]*([ \\t]*")
          (setq point-start (point))
          (forward-sexp)
          (buffer-substring-no-properties point-start (point)))
      (error nil))))

(defun scala-plus:guess-spec-name ()
  "Returns the spec name; first, it looks for a funspec pattern, then, wordspec."
  (or (scala-plus:guess-funspec-name) (scala-plus:guess-wordspec-name)))

(defun scala-plus:guess-outer-class ()
  "Returns outer class name containing the current point. Requires class name to be indented fully left."
  (let ((point-start))
    (save-excursion
      (search-backward-regexp "^class *")
      (search-forward-regexp "^class *")
      (setq point-start (point))
      (search-forward-regexp "[^0-9a-z._]")
      (buffer-substring-no-properties point-start (- (point) 1)))))

(defun scala-plus:source-root (path)
  "Given an absolute directory, returns /path/to/src/{main,test}/scala."
  (replace-regexp-in-string
   "\\(src/\\(test\\|main\\)/scala/\\).+$"
   "\\1"
   path))

(defun scala-plus:package-name-from-directory (path)
  "Given an absolute path, returns a package name.

IE:
  (scala-plus:package-name-from-directory \"/Users/path/projects/project/src/main/scala/com/project/authentication/db/\") returns

; => \"com.project.authentication.db\""
  (let* ((parent-path (scala-plus:source-root path))
         (local-path (replace-regexp-in-string (format "^%s" (regexp-quote parent-path)) "" path))
         (path-fragment (replace-regexp-in-string "\\(^/\\|/$\\)" "" local-path)))
    (replace-regexp-in-string "/" "." path-fragment)))

(defun scala-plus:set-package-name ()
  (interactive)
  (let ((package-name (scala-plus:package-name-from-directory (file-name-directory (buffer-file-name)))))
    (message package-name)
    (save-excursion
      (goto-char 0)
      (if (looking-at "package ")
          (kill-line)
        (progn
          (insert "\n")
          (goto-char 0)))
      (insert "package ")
      (insert package-name))))


(eval-after-load 'scala-mode
  '(progn
     (define-key scala-mode-map (kbd "s-R") 'scala-plus:yank-sbt-test-only)
     (define-key scala-mode-map (kbd "C-c , t") 'scala-test:toggle-spec-test)
     (define-key scala-mode-map (kbd "C-c p") 'scala-plus:set-package-name)
     (define-key scala-mode-map (kbd "C-c f") 'insert-file-basename)
     (add-hook 'scala-mode-hook 'scala-plus:set-imenu-generic-expression)))

(provide 'scala-plus)
