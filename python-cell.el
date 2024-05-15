;;; python-cell.el --- Support for MATLAB-like cells in python mode -*- lexical-binding: t; -*-

;; Copyright (C) 2013 Thomas Hisch.
;; Author: Thomas Hisch <t.hisch@gmail.com>
;; Maintainer: Thomas Hisch <t.hisch@gmail.com>
;; URL: https://github.com/thisch/python-cell.el
;; Version: 1.0
;; Package-Requires: ((emacs "25.1"))
;; Created: 2013-07-05
;; Keywords: extensions, python, matlab, cell

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Major parts of the highlighting code were taken from hl-line-mode.el.

;;; Code:

(require 'python)

(defgroup python-cell nil
  "MATLAB-like cells in python mode."
  :group 'python)

(defface python-cell-highlight-face
  '((t :inherit highlight))
  "Default face for highlighting the current cell in Python-Cell mode."
  :group 'python-cell)

(defface python-cell-cellbreak-face
  '((t :weight bold :overline t))
  "Default face for the cell separation line in Python-Cell mode."
  :group 'python-cell)

(defcustom python-cell-highlight-cell t
  "Non-nil tells Python-Cell mode to highlight the current cell."
  :type 'boolean
  :group 'python-cell
  :safe 'booleanp)

(defcustom python-cell-cellbreak-regexp
  (rx line-start (* space)
      (group (and "#" (or (and "#" space (* (not (any "\n"))))
                          (and " <" (or "codecell" "markdowncell") ">"))
                  line-end)))
  "Regexp used for detecting the cell boundaries of code cells/blocks."
  :type 'string
  :group 'python-cell
  :safe 'stringp)

(defvar python-cell-mode)

(defvar python-cell-overlay nil
  "Overlay used by Python-Cell mode to highlight the current cell.")
(make-variable-buffer-local 'python-cell-overlay)

(defcustom python-cell-highlight-face 'python-cell-highlight-face
  "Face with which to highlight the current cell in Python-Cell mode."
  :type 'face
  :group 'python-cell
  :set (lambda (symbol value)
         (set symbol value)
         (dolist (buffer (buffer-list))
           (with-current-buffer buffer
             (when python-cell-overlay
               (overlay-put python-cell-overlay 'face python-cell-highlight-face))))))

(defcustom python-cell-sticky-flag nil
  "Non-nil means the Python-Cell mode highlight appears in all windows.
Otherwise Python-Cell mode will highlight only in the selected
window.  Setting this variable takes effect the next time you use
the command `python-cell-mode' to turn Python-Cell mode on."
  :type 'boolean
  :group 'python-cell)

(defcustom python-cell-run-region-fn 'shell
  "Choice of backend to use for python-cell interactions. Available options are
`jupyter` and `shell`."
  :options '(shell jupyter)
  :type 'symbol
  :group 'python-cell)

;; Navigation

(defun python-cell-move-cell-up (&optional arg)
  "Move the contents of the current cell up.
Optionally a prefix argument ARG can be provided for repeating it a
bunch of times."
  (interactive "p")

  (dotimes (_ (or arg 1))
    (let ((rngc (python-cell-range-function))
	  (rngp (save-excursion (python-cell-backward-cell)
				(python-cell-range-function))))    
      (goto-char (car rngp))
      (kill-region (car rngc) (cdr rngc))
      (yank)
      (python-cell-backward-cell)))
  )

(defun python-cell-move-cell-down (&optional arg)
  "Move the contents of the current cell down.
Optionally a prefix argument ARG can be provided for repeating it a
  bunch of times." 
  (interactive "p")

  (dotimes (_ (or arg 1))
    (let ((rngc (python-cell-range-function))
	  (rngn (save-excursion (python-cell-forward-cell)
				(python-cell-range-function))))    
      (goto-char (cdr rngn))
      (kill-region (car rngc) (cdr rngc))
      (yank)
      (forward-char -1)
      (python-cell-beginning-of-cell)))
  )

(defun python-cell-forward-cell  (&optional arg)
  (interactive "p")

  (dotimes (_ (or arg 1))
    (python-cell-end-of-cell)
    (if (re-search-forward python-cell-cellbreak-regexp nil t)
	(progn (end-of-line)
               (forward-char 1))
      (goto-char (point-max)))))

(defun python-cell-backward-cell  (&optional arg)
  (interactive "p")

  (dotimes (_ (or arg 1))  
    (python-cell-beginning-of-cell)
    (forward-char -1)
    (beginning-of-line)
    (and (save-excursion (re-search-backward python-cell-cellbreak-regexp
                                             nil t))
	 (= (match-beginning 0) (save-excursion
                                  (forward-char -1) (beginning-of-line) (point)))
	 (goto-char (match-beginning 0)))

    (if (> (point) (point-min))
	(forward-char -1))
    (if (re-search-backward python-cell-cellbreak-regexp nil t)
	(progn (goto-char (match-end 0))
               (end-of-line)
               (forward-char 1))
      (goto-char (point-min)))))

(defun python-cell-beginning-of-cell (&optional arg)
  (interactive "p")
  ;; TODO: prefix support ?

  (end-of-line)
  (if (re-search-backward python-cell-cellbreak-regexp nil t)
      (progn (goto-char (match-end 0))
             (end-of-line)
             (forward-char 1))
    (goto-char (point-min)))
  (point))

(defun python-cell-end-of-cell (&optional arg)
  (interactive "p")
  ;; TODO: prefix support ?

  (end-of-line)
  (if (re-search-forward python-cell-cellbreak-regexp nil t)
      (progn (goto-char (match-beginning 0))
             (forward-char -1))
    (goto-char (point-max)))
  (point))


(declare-function jupyter-eval-region "jupyter-client.el" (insert beg end))
(defun python-cell-shell-send-cell ()
  "Send the cell the cursor is in to the inferior Python process."
  (interactive)
  (let (
        (start (save-excursion (python-cell-beginning-of-cell)
                               (point)))
        (end (save-excursion (python-cell-end-of-cell)
                             (point))))
    ;; (goto-char end)
    ;; (push-mark start)
    ;; (activate-mark)))
    (pcase python-cell-run-region-fn
      ('shell (python-shell-send-region start end))
      ('jupyter (jupyter-eval-region nil start end)))))

(defun python-cell-run-till-point ()
  "Run all cells until point, not including the cell point is in."
  (interactive)
  (let ((pt (point)))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (>= pt (point))
          (python-cell-shell-send-cell)
          (python-cell-forward-cell)
          (python-cell-end-of-cell))))))

;;; Cell Highlighting

(defun python-cell-range-function ()
  "Function to call to return highlight range.
The function of no args should return a cons cell; its car value
is the beginning position of highlight and its cdr value is the
end position of highlight in the buffer.
It should return nil if there's no region to be highlighted."
  (save-match-data
    (let ((r-start (save-excursion
                     (progn (end-of-line)
                            (if (re-search-backward python-cell-cellbreak-regexp nil t)
                                (progn (goto-char (match-beginning 0))
                                       (point))
                              (point-min)))))
          (r-end (save-excursion
                   (progn (end-of-line)
                          (if (re-search-forward python-cell-cellbreak-regexp nil t)
                              (progn (goto-char (match-beginning 0))
                                     (point))
                            (point-max))))))
      (progn
        ;; (message "cp is %s start is %s; end is %s" (point) r-start r-end)
        (if (and (eq r-start (point-min)) (eq r-end (point-max)))
            nil
          `(,r-start . ,r-end))))))

(defun python-cell-highlight ()
  "Activate the Python-Cell overlay on the current line."
  (if python-cell-mode  ; Might be changed outside the mode function.
      (progn
        (unless python-cell-overlay
          (setq python-cell-overlay (make-overlay 1 1)) ; to be moved
          (overlay-put python-cell-overlay 'face python-cell-highlight-face))
        (overlay-put python-cell-overlay
                     'window (unless python-cell-sticky-flag (selected-window)))
        (python-cell-move python-cell-overlay))
    (python-cell-unhighlight)))

(defun python-cell-unhighlight ()
  "Deactivate the Python-Cell overlay on the current line."
  (when python-cell-overlay
    (delete-overlay python-cell-overlay)))

(defun python-cell-move (overlay)
  "Move the Python-Cell overlay."
  (if-let ((start-end (python-cell-range-function)))
      (move-overlay overlay (car start-end) (cdr start-end))
    (move-overlay overlay 1 1)))

(defun python-cell-setup-cellhighlight ()
  ;; In case `kill-all-local-variables' is called.
  (add-hook 'change-major-mode-hook #'python-cell-unhighlight nil t)
  (if python-cell-sticky-flag
      (remove-hook 'pre-command-hook #'python-cell-unhighlight t)
    (add-hook 'pre-command-hook #'python-cell-unhighlight nil t))
  (python-cell-highlight)
  (add-hook 'post-command-hook #'python-cell-highlight nil t))

;;; Keymap

(defvar python-cell-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [(control return)] 'python-cell-shell-send-cell)
    (define-key map [(control down)] 'python-cell-forward-cell)
    (define-key map [(control up)] 'python-cell-backward-cell)
    map)
  "Key map for Python-Cell minor mode.")

(defalias 'python-cell-what-cell #'what-page)
(defalias 'python-cell-narrow-to-cell #'narrow-to-page)

;;; Minor mode:

;;;###autoload
(define-minor-mode python-cell-mode
  "Highlight MATLAB-like cells and navigate between them."
  :keymap python-cell-mode-map
  (let ((arg `((,python-cell-cellbreak-regexp 1 'python-cell-cellbreak-face prepend))))
    (if (not python-cell-mode) ;; OFF
        (font-lock-remove-keywords nil arg)
      (make-local-variable 'page-delimiter)
      (setq page-delimiter python-cell-cellbreak-regexp)
      (font-lock-add-keywords nil arg)
      (when python-cell-highlight-cell
        (python-cell-setup-cellhighlight))))
  (font-lock-flush))

;;;###autoload
(defun python-cell-mode-enable ()
  (python-cell-mode 1))

;;;###autoload
(defun python-cell-mode-disable ()
  (python-cell-mode 0))

(provide 'python-cell)
;;; python-cell.el ends here
