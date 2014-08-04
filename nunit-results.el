;; nunit-results.el --- Display NUnit test results in Emacs

;; Copyright (C) 2014 Sasha Kovar

;; Author: Sasha Kovar <sasha-emacs@arcocene.org>
;; Keywords: languages

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

;; M-x nunit-results-show
;;
;; Display a formatted report of NUnit test results in a buffer.
;; Parses TestResult.xml, which should be dropped by running
;; nunit-console.  Running nunit-console is out of scope of this
;; package.
;;
;; M-x nunit-results-watch
;;
;; Check TestResult.xml periodically and pop up the results buffer
;; when there are changes.
;;
;; M-x nunit-results-stop-watching
;;
;; Stop the watcher.
;;
;;
;; Installation:
;;
;; Put nunit-results.el into your `load-path'
;; and add (require 'nunit-results) to your init file.

;;; Code:


(put 'nunit-results-mode 'mode-class 'special)
(define-derived-mode nunit-results-mode special-mode "NUnit test results"
                     "Major mode for displaying results from nunit-console.")

(defface nunit-results-success
    '((((class color))
       :background "green" :foreground "green")
      (((type tty) (class mono))
       :inverse-video t))
  "Face used to display a successful test result."
  :group 'nunit-results)

(defface nunit-results-error
    '((((class color))
       :background "orange" :foreground "orange")
      (((type tty) (class mono))
       :inverse-video t))
  "Face used to display an successful test result."
  :group 'nunit-results)

(defface nunit-results-failure
    '((((class color))
       :background "red" :foreground "red")
      (((type tty) (class mono))
       :inverse-video t))
  "Face used to display a successful test result."
  :group 'nunit-results)

(defcustom nunit-results-default-filename "TestResult.xml"
  "Default filename for the test results file written by the
nunit process."
  :group 'nunit-results)

(defun nunit-results-default-dir ()
    (locate-dominating-file default-directory
                            nunit-results-default-filename))

(defun nunit-results-default-file ()
  (let* ((file nunit-results-default-filename)
         (dir (nunit-results-default-dir)))
    (when dir (concat dir file))))

(defun nunit-results-find-file ()
  (read-file-name "Test results file: "
                  (nunit-results-default-dir)
                  nil nil
                  nunit-results-default-filename))

(defun nunit-results-search-tree (xml fun)
  (when (consp xml)
    (append (and (funcall fun xml) (list xml))
            (nunit-results-search-tree (car xml) fun)
            (nunit-results-search-tree (cdr xml) fun))))

(defun nunit-results-is-test-case (elt)
  (and (listp elt) (eq (xml-node-name elt) 'test-case)))

(defun nunit-results-show (file)
  (interactive (list (nunit-results-find-file)))
  (nunit-results-show-file file))

(defun nunit-results-show-file (file)
  (flet ((key (key alist)
           (string-to-int (cdr (assoc key alist))))

         (insert-colored (count char face)
           (let ((start (point)))
             (dotimes (i count)
               (insert char))
             (add-text-properties start (point) `(face ,face)))))

    (let* ((results-buf (get-buffer-create "*Nunit-tests*"))
           (xml (xml-parse-file file))
           (attrs (xml-node-attributes (first xml)))
           (total (key 'total attrs))
           (errors (key 'errors attrs))
           (failures (key 'failures attrs))
           (success (- total failures))
           (cases (nunit-results-search-tree xml 'nunit-results-is-test-case)))

      (with-current-buffer results-buf
        (nunit-results-mode)

        (let ((inhibit-read-only t)
              (buffer-undo-list t))
          (erase-buffer)

          ;; summary
          (insert (format "%s\n\n%s Errors, %s Failures, %s Success, %s Total\n\n"
                          file
                          errors failures success total))

          (insert-colored errors   "E" 'nunit-results-error)
          (insert-colored failures "F" 'nunit-results-failure)
          (insert-colored success  "S" 'nunit-results-success)

          (insert "\n\n")

          ;; list failures
          (let (fails)
            (dolist (c cases)
              (let* ((case-attrs (xml-node-attributes c))
                     (name (cdr (assoc 'name case-attrs)))
                     (success (cdr (assoc 'success case-attrs))))
                (when (string= success "False")
                  (push name fails))))

            (when fails
              (insert "Failures:\n")
              (dolist (f fails)
                (insert "\t" f "\n"))))

          (setq next-error-last-buffer results-buf)
          (setq buffer-read-only t)
          (set-buffer-modified-p nil)
          (switch-to-buffer results-buf))))))


;;; For monitoring a TestResult.xml file for changes

(defvar nunit-results-monitor-attributes nil
  "Cached file attributes to be monitored.")

(defvar nunit-results-timer nil
  "Holds a timer object if we're watching a file.")

(defun nunit-results-stop-watching ()
  (interactive)
  (when nunit-results-timer
    (message "Cancelling nunit-results watcher.")
    (cancel-timer nunit-results-timer)
    (setq nunit-results-timer nil)))

(defun nunit-results-watch (file)
  (interactive (list (nunit-results-find-file)))
  (nunit-results-stop-watching)
  (message "Starting nunit-results watcher.")
  (setq nunit-results-timer
        (run-with-timer
         0 5
         (lambda (f)
           (let ((att (file-attributes f)))
             (unless (or (null nunit-results-monitor-attributes)
                         (equalp nunit-results-monitor-attributes att))
               (nunit-results-show f))
             (setq nunit-results-monitor-attributes att)))
         file)))


(provide 'nunit-results)
