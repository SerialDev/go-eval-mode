;;; igo-eval.el --- Igo-Eval minor mode for Go Repl support

;; Copyright (C) 2018 Andres Mariscal

;; Author: Andres Mariscal <carlos.mariscal.melgar@gmail.com>
;; Created: 1 May 2018
;; Version: 0.0.1
;; Keywords: go languages repl
;; URL: https://github.com/serialdev/igo-eval-mode
;; Package-Requires: ((emacs "24.3", go-mode ))
;;; Commentary:
;; Go Repl support through igo-eval repl

;; Usage


(defun get-last-sexp (&optional bounds)
  "Return the sexp preceding the point."
  (interactive)
  (let ((points     (save-excursion
           (list (point)
                 (progn (backward-sexp 1)
                        (skip-chars-forward "[:blank:]")
                        (when (looking-at-p "\n") (forward-char 1))
                        (point)))) ))
    (buffer-substring-no-properties  (car points) (cadr points) )
  ))


(defun igo-eval-eval-last-sexp (begin end)
  "Evaluate last sexp."
  (interactive "r")
  (igo-eval t)
  (progn
    (maintain-indentation (igo-eval-split "\n"
				      (get-last-sexp)) 0)
    (comint-send-string igo-eval-shell-buffer-name "\n")
  ))

(defun regex-match ( regex-string string-search match-num )
  (string-match regex-string string-search)
  (match-string match-num string-search))


(defcustom igo-eval-shell-buffer-name "*Igo-Eval*"
  "Name of buffer for igo-eval."
  :group 'igo-eval
  :type 'string)

(defun igo-eval-is-running? ()
  "Return non-nil if igo-eval is running."
  (comint-check-proc igo-eval-shell-buffer-name))
(defalias 'igo-eval-is-running-p #'igo-eval-is-running?)

;;;###autoload
(defun igo-eval (&optional arg)
  "Run igo-eval.
Unless ARG is non-nil, switch to the buffer."
  (interactive "P")
  (let ((buffer (get-buffer-create igo-eval-shell-buffer-name)))
    (unless arg
      (pop-to-buffer buffer))
    (unless (igo-eval-is-running?)
      (with-current-buffer buffer
        (igo-eval-startup)
        (inferior-igo-eval-mode)
	)
      (pop-to-buffer buffer)
      (other-window -1)
      )
    ;; (with-current-buffer buffer (inferior-igo-eval-mode))
    buffer))



;;;###autoload
(defalias 'run-igo-eval #'igo-eval)
;;;###autoload
(defalias 'inferior-igo-eval #'igo-eval)


(defun igo-eval-startup ()
  "Start igo-eval."
  (comint-exec igo-eval-shell-buffer-name "igo-eval" igo-eval-program nil igo-eval-args))

(defun maintain-indentation (current previous-indent)
  (when current
    (let ((current-indent (length (igo-eval-match-indentation (car current)))))
      (if (< current-indent previous-indent)
	  (progn
	    (comint-send-string igo-eval-shell-buffer-name "\n")
	    (comint-send-string igo-eval-shell-buffer-name (car current))
	    (comint-send-string igo-eval-shell-buffer-name "\n"))
      (progn
	(comint-send-string igo-eval-shell-buffer-name (car current))
	(comint-send-string igo-eval-shell-buffer-name "\n")))
      (maintain-indentation (cdr current) current-indent)
      )))

(defun igo-eval-split (separator s &optional omit-nulls)
  "Split S into substrings bounded by matches for regexp SEPARATOR.
If OMIT-NULLS is non-nil, zero-length substrings are omitted.
This is a simple wrapper around the built-in `split-string'."
  (declare (side-effect-free t))
  (save-match-data
    (split-string s separator omit-nulls)))


(defun igo-eval-match-indentation(data)
  (regex-match "^[[:space:]]*" data 0))


(defun igo-eval-eval-region (begin end)
  "Evaluate region between BEGIN and END."
  (interactive "r")
  (igo-eval t)
  (progn
    (maintain-indentation (igo-eval-split "\n"
				      (buffer-substring-no-properties begin end)) 0)
    (comint-send-string igo-eval-shell-buffer-name ";\n")
  ))



(defun igo-eval-parent-directory (dir)
  (unless (equal "/" dir)
    (file-name-directory (directory-file-name dir))))

(defun igo-eval-find-file-in-hierarchy (current-dir fname)
  "Search for a file named FNAME upwards through the directory hierarchy, starting from CURRENT-DIR"
  (let ((file (concat current-dir fname))
        (parent (igo-eval-parent-directory (expand-file-name current-dir))))
    (if (file-exists-p file)
        file
      (when parent
        (igo-eval-find-file-in-hierarchy parent fname)))))


(defun igo-eval-get-string-from-file (filePath)
  "Return filePath's file content.
;; thanks to “Pascal J Bourguignon” and “TheFlyingDutchman 〔zzbba…@aol.com〕”. 2010-09-02
"
  (with-temp-buffer
    (insert-file-contents filePath)
    (buffer-string)))


(defun igo-eval-eval-buffer ()
  "Evaluate complete buffer."
  (interactive)
  (igo-eval-eval-region (point-min) (point-max)))

(defun igo-eval-eval-line (&optional arg)
  "Evaluate current line.
If ARG is a positive prefix then evaluate ARG number of lines starting with the
current one."
  (interactive "P")
  (unless arg
    (setq arg 1))
  (when (> arg 0)
    (igo-eval-eval-region
     (line-beginning-position)
     (line-end-position arg))))


;;; Shell integration

(defcustom igo-eval-shell-interpreter "igo-eval"
  "default repl for shell"
  :type 'string
  :group 'igo-eval)

(defcustom igo-eval-shell-internal-buffer-name "Igo-Eval Internal"
  "Default buffer name for the internal process"
  :type 'string
  :group 'igo-eval
  :safe 'stringp)


(defcustom igo-eval-shell-prompt-regexp "> "
  "Regexp to match prompts for igo-eval.
   Matchint top\-level input prompt"
  :group 'igo-eval
  :type 'regexp
  :safe 'stringp)

(defcustom igo-eval-shell-prompt-block-regexp " "
  "Regular expression matching block input prompt"
  :type 'string
  :group 'igo-eval
  :safe 'stringp)

(defcustom igo-eval-shell-prompt-output-regexp ""
  "Regular Expression matching output prompt of evxcr"
  :type 'string
  :group 'igo-eval
  :safe 'stringp)

(defcustom igo-eval-shell-enable-font-lock t
  "Should syntax highlighting be enabled in the igo-eval shell buffer?"
  :type 'boolean
  :group 'igo-eval
  :safe 'booleanp)

(defcustom igo-eval-shell-compilation-regexp-alist '(("[[:space:]]\\^+?"))
  "Compilation regexp alist for inferior igo-eval"
  :type '(alist string))

(defgroup igo-eval nil
  "Go interactive mode"
  :link '(url-link "https://github.com/serialdev/igo-eval-mode")
  :prefix "igo-eval"
  :group 'languages)

(defcustom igo-eval-program (executable-find "go-eval")
  "Program invoked by `igo-eval'."
  :group 'igo-eval
  :type 'file)


(defcustom igo-eval-args nil
  "Command line arguments for `igo-eval-program'."
  :group 'igo-eval
  :type '(repeat string))



(defcustom igo-eval-prompt-read-only t
  "Make the prompt read only.
See `comint-prompt-read-only' for details."
  :group 'igo-eval
  :type 'boolean)

(defun igo-eval-comint-output-filter-function (output)
  "Hook run after content is put into comint buffer.
   OUTPUT is a string with the contents of the buffer"
  (ansi-color-filter-apply output))



(define-derived-mode inferior-igo-eval-mode comint-mode "Igo-Eval"
  (setq comint-process-echoes t)
  (setq comint-prompt-regexp "> ")

  (setq mode-line-process '(":%s"))
  (make-local-variable 'comint-output-filter-functions)
  (add-hook 'comint-output-filter-functions
  	    'igo-eval-comint-output-filter-function)
  (set (make-local-variable 'compilation-error-regexp-alist)
       igo-eval-shell-compilation-regexp-alist)
  (setq comint-use-prompt-regexp t)
  (setq comint-inhibit-carriage-motion nil)
  (setq-local comint-prompt-read-only igo-eval-prompt-read-only)
  (when igo-eval-shell-enable-font-lock
    (set-syntax-table igo-eval-mode-syntax-table)
    (set (make-local-variable 'font-lock-defaults)
	 '(igo-eval-mode-font-lock-keywords nil nil nil nil))
    (set (make-local-variable 'syntax-propertize-function)
    	 (eval
    	  "Unfortunately eval is needed to make use of the dynamic value of comint-prompt-regexp"
    	  '(syntax-propertize-rules
    	    '(comint-prompt-regexp
    	       (0 (ignore
    		   (put-text-property
    		    comint-last-input-start end 'syntax-table
    		    python-shell-output-syntax-table)
    		   (font-lock-unfontify--region comint-last-input-start end))))
    	    )))
    (compilation-shell-minor-mode 1)))

(progn
  (define-key igo-eval-mode-map (kbd "C-c C-b") #'igo-eval-eval-buffer)
  (define-key igo-eval-mode-map (kbd "C-c C-r") #'igo-eval-eval-region)
  (define-key igo-eval-mode-map (kbd "C-c C-l") #'igo-eval-eval-line)
  (define-key igo-eval-mode-map (kbd "C-c C-s") #'igo-eval-eval-last-sexp)
  (define-key igo-eval-mode-map (kbd "C-c C-p") #'igo-eval))

;;;###autoload

(provide 'igo-eval)

;;; igo-eval.el ends here
