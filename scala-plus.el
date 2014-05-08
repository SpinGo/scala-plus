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

(defun scala-plus:yank-sbt-test-only ()
  "Copies expression necessary to run the current test suite in an sbt repl"
  (interactive)
  (let ((cmd (format "test-only %s.%s" (scala-plus:buffer-package-name) (scala-plus:guess-outer-class))))
    (kill-new cmd)
    (message "Copied '%s' to the killring" cmd)))

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


(defun scala-test:toggle-spec-test ()
  "Toggle between test and spec"
  (interactive)
  (let* ((path buffer-file-name)
         (spec-regex "^\\(.+\\)/src/test/scala/\\(.+\\)Spec\\.scala" )
         (main-regex "^\\(.+\\)/src/main/scala/\\(.+\\)\\.scala")
         (other-path 
          (cond ((string-match spec-regex path)
                 (format "%s/src/main/scala/%s.scala" 
                         (match-string 1 path)
                         (match-string 2 path)))
                ((string-match main-regex path)
                 (format "%s/src/test/scala/%sSpec.scala" 
                         (match-string 1 path)
                         (match-string 2 path))))))
    (message "%s" other-path)
    (find-file other-path)))


;;; general scala helpers

(defun scala-plus:buffer-package-name ()
  "Pulls the package name from the current file"
  (let ((point-start))
    (save-excursion
      (goto-char 0)
      (search-forward-regexp "^ *package *")
      (setq point-start (point))
      (search-forward-regexp "[^0-9a-z._]")
      (buffer-substring-no-properties point-start (- (point) 1)))))

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


(eval-after-load 'scala-mode2
  '(progn
     (define-key scala-mode-map (kbd "s-R") 'scala-plus:yank-sbt-test-only)
     (define-key scala-mode-map (kbd "C-c , t") 'scala-test:toggle-spec-test)
     (define-key scala-mode-map (kbd "C-c p") 'scala-plus:set-package-name)
     (add-hook 'scala-mode-hook 'scala-plus:set-imenu-generic-expression)))

(provide 'scala-plus)
