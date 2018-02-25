;;; -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Tobias Pisani

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and-or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Code:

(require 'cquery-common)
(require 'cquery-tree)

;; ---------------------------------------------------------------------
;;   Tree node
;; ---------------------------------------------------------------------

(cl-defstruct cquery-member-tree-node
  name
  field-name
  id)

(defun cquery-member-tree--read-node (data &optional parent)
  "Construct a call tree node from hashmap DATA and give it the parent PARENT"
  (let* ((location (gethash "location" data))
         (filename (string-remove-prefix lsp--uri-file-prefix (gethash "uri" location)))
         (node
          (make-cquery-tree-node
           :location (cons filename (gethash "start" (gethash "range" location)))
           :has-children (< 0 (gethash "numChildren" data))
           :parent parent
           :expanded nil
           :children nil
           :data (make-cquery-member-tree-node
                  :name (gethash "name" data)
                  :field-name (gethash "field_name" data)
                  :id (gethash "id" data)))))
    (setf (cquery-tree-node-children node)
          (--map (cquery-member-tree--read-node it node)
                 (gethash "children" data)))
    node))

(defun cquery-member-tree--request-children (node)
  "."
  (let ((id (cquery-member-tree-node-id (cquery-tree-node-data node))))
    (--map (cquery-member-tree--read-node it node)
           (gethash "children" (lsp--send-request
                                (lsp--make-request "$cquery/memberHierarchyExpand"
                                                   `(:id ,id
                                                         :levels 1)))))))

(defun cquery-member-tree--request-init ()
  "."
  (cquery--cquery-buffer-check)
  (list
   (lsp--send-request
    (lsp--make-request "$cquery/memberHierarchyInitial"
                       `(
                         :textDocument (:uri ,(concat lsp--uri-file-prefix buffer-file-name))
                         :position ,(lsp--cur-position)
                         :levels 1)))))

(defun cquery-member-tree--make-string (node depth)
  "Propertize the name of NODE with the correct properties"
  (let ((data (cquery-tree-node-data node)))
    (cquery--render-string (if (eq depth 0)
                               (cquery-member-tree-node-name data)
                             (format "%s %s"
                                     (cquery-member-tree-node-name data)
                                     (cquery-member-tree-node-field-name data))))))

(defun cquery-member-tree ()
  (interactive)
  (cquery--cquery-buffer-check)
  (cquery-tree--open
   (make-cquery-tree-client
    :name "member hierarchy"
    :mode-line-format (propertize "Member hierarchy" 'face 'cquery-tree-mode-line-face)
    :top-line-f (lambda () (propertize "Members of" 'face '(:height 0.8 :inherit cquery-tree-mode-line-face)))
    :make-string-f 'cquery-member-tree--make-string
    :read-node-f 'cquery-member-tree--read-node
    :request-children-f 'cquery-member-tree--request-children
    :request-init-f 'cquery-member-tree--request-init)))

(provide 'cquery-member-tree)
;;; cquery-member-tree.el ends here
