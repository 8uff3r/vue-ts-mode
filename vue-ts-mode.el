;;; vue-ts-mode.el --- Major mode for editing Vue templates  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 8uff3r

;; Author: 8uff3r <8uff3r@gmail.com>
;; Homepage: https://github.com/8uff3r/vue-ts-mode
;; Version: 1.0.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages


;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a major mode with syntax highlighting for Vue
;; templates. It leverages Emacs' built-in tree-sitter support, as well as
;; ikatyang's tree-sitter grammar for Vue.

;; More info:
;; README: https://github.com/8uff3r/vue-ts-mode
;; tree-sitter-vue: https://github.com/ikatyang/tree-sitter-vue
;; Vue: https://vuejs.org//

;;; Code:

(require 'treesit)
(require 'typescript-ts-mode)
(require 'css-mode)


(defgroup vue ()
  "Major mode for editing Vue templates."
  :group 'languages)

;; Indent Rules

(defcustom vue-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `vue-ts-mode'."
  :type 'integer
  :group 'vue
  :package-version '(vue-ts-mode . "1.0.0"))

(defvar vue-ts-mode--indent-rules
  `((vue
     ((node-is "/>") parent-bol 0)
     ((node-is ">") parent-bol 0)
     ((node-is "end_tag") parent-bol 0)
     ((parent-is "comment") prev-adaptive-prefix 0)
     ((parent-is "element") parent-bol vue-ts-mode-indent-offset)
     ((parent-is "script_element") parent-bol vue-ts-mode-indent-offset)
     ((parent-is "style_element") parent-bol vue-ts-mode-indent-offset)
     ((parent-is "template_element") parent-bol vue-ts-mode-indent-offset)
     ((parent-is "start_tag") parent-bol vue-ts-mode-indent-offset)
     ((parent-is "self_closing_tag") parent-bol vue-ts-mode-indent-offset))
    (css . ,(append (alist-get 'css css--treesit-indent-rules)
                    '(((parent-is "stylesheet") parent-bol 0))))
    (tsx . ,(alist-get 'tsx (typescript-ts-mode--indent-rules 'tsx))))
  "Tree-sitter indentation rules for `vue-ts-mode'.")

;; font-lock rules
(defface vue-ts-mode-template-tag-face
    '((t  :foreground "#ff757f"))
  "Face for template tags."
  :group 'vue-ts-mode-faces)

(defface vue-ts-mode-template-tag-bracket-face
    '((t :foreground "#86e1fc"))
  "Face for html tags angle brackets (<, > and />)."
  :group 'vue-ts-mode-faces)

(defun vue-ts-mode--prefix-font-lock-features (prefix settings)
  "Prefix with PREFIX the font lock features in SETTINGS."
  (mapcar (lambda (setting)
            (list (nth 0 setting)
                  (nth 1 setting)
                  (intern (format "%s-%s" prefix (nth 2 setting)))
                  (nth 3 setting)))
          settings))


(defvar vue-font-lock-settings
  (append
   (vue-ts-mode--prefix-font-lock-features
    "tsx"
    (typescript-ts-mode--font-lock-settings 'tsx))

   (vue-ts-mode--prefix-font-lock-features
    "css" css--treesit-settings)

   (treesit-font-lock-rules

    :language 'vue
    :override t
    :feature 'vue-ref
    '((element (_ (attribute
                   (attribute_name)
                   @font-lock-type-face
                   (:equal @font-lock-type-face "ref")
                   (quoted_attribute_value
                    (attribute_value)
                    @font-lock-variable-name-face)))))

    :language 'vue
    :feature 'vue-sp-dir
    '((_ (_ (directive_attribute
             (directive_name)
             @font-lock-type-face
             (:match "\\`\\(v-if\\|v-for\\|v-model\\|v-else\\)\\'"
                     @font-lock-type-face)))))


    :language 'vue
    :feature 'vue-attr
    '((attribute_name) @font-lock-property-name-face)

    :language 'vue
    :feature 'vue-definition
    '((tag_name) @vue-ts-mode-template-tag-face)

    :language 'vue
    :feature 'vue-directive
    '((_ (_
          (directive_attribute
           (directive_name) @font-lock-keyword-face
           (directive_argument) @font-lock-type-face))))

    :language 'vue
    :feature 'vue-bracket
    '(([ "{{" "}}" "<" ">" "</" "/>"]) @vue-ts-mode-template-tag-bracket-face)

    :language 'vue
    :feature 'vue-string
    '((quoted_attribute_value) @font-lock-string-face))))

(defvar vue-ts-mode--range-settings
  (treesit-range-rules

   :embed 'tsx
   :host 'vue
   '(((script_element (raw_text) @capture))

     (interpolation (raw_text) @capture)

     (directive_attribute
      (quoted_attribute_value
       (attribute_value) @capture)))

   :embed 'css
   :host 'vue
   '((style_element (raw_text) @capture))))

(defun vue-ts-mode--advice-for-treesit-buffer-root-node (&optional lang)
  "Return the current ranges for the LANG parser in the current buffer.

If LANG is omitted, return ranges for the first language in the parser list.

If `major-mode' is currently `vue-ts-mode', or if LANG is vue, this function
instead always returns t."
  (if (or (eq lang 'vue) (not (eq major-mode 'vue-ts-mode)))
    t
    (treesit-parser-included-ranges
     (treesit-parser-create

      (or lang (treesit-parser-language (car (treesit-parser-list))))))))

(defun vue-ts-mode--advice-for-treesit--merge-ranges (_ new-ranges _ _)
  "Return truthy if `major-mode' is `vue-ts-mode', and if NEW-RANGES is non-nil."
  (and (eq major-mode 'vue-ts-mode) new-ranges))

(defun vue-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (when (equal (treesit-node-type node) "tag_name")
    (treesit-node-text node t)))

(defun vue-ts-mode--treesit-language-at-point (point)
  "Return the language at POINT."
  (let* ((range nil)
         (language-in-range
          (cl-loop
           for parser in (treesit-parser-list)
           do (setq range
                    (cl-loop
                     for range in (treesit-parser-included-ranges parser)
                     if (and (>= point (car range)) (<= point (cdr range)))
                     return parser))
           if range
           return (treesit-parser-language parser))))
    (or language-in-range 'vue)))
;;;###autoload
(define-derived-mode vue-ts-mode prog-mode "Vue-ts"
  "Major mode for editing Vue templates, powered by tree-sitter."
  :group 'vue
  ;; :syntax-table html-mode-syntax-table

  (unless (treesit-ready-p 'vue)
    (error "Tree-sitter grammar for Vue isn't available"))

  (unless (treesit-ready-p 'css)
    (error "Tree-sitter grammar for CSS isn't available"))

  (unless (treesit-ready-p 'tsx)
    (error "Tree-sitter grammar for Typescript/TYPESCRIPT isn't available"))

  (when (treesit-ready-p 'tsx)
    (treesit-parser-create 'vue)

    ;; Comments and text content
    (setq-local treesit-text-type-regexp
                (regexp-opt '("comment" "text")))

    ;; Indentation rules
    (setq-local treesit-simple-indent-rules vue-ts-mode--indent-rules
                css-indent-offset vue-ts-mode-indent-offset)

    ;; Font locking
    (setq-local treesit-font-lock-settings vue-font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((vue-attr vue-definition css-selector
                   css-comment css-query css-keyword
                   tsx-comment tsx-declaration)
                  (vue-ref vue-string vue-directive css-property css-constant
                           css-string
                           tsx-keyword
                           tsx-string tsx-escape-sequence)
                  (vue-sp-dir css-error css-variable css-function
                              css-operator
                              tsx-constant
                              tsx-expression tsx-identifier
                              tsx-number tsx-pattern
                              tsx-operator
                              tsx-property)
                  (vue-bracket css-bracket
                                tsx-function
                                tsx-bracket
                                tsx-delimiter)))


    ;; Embedded languages
    (setq-local treesit-range-settings vue-ts-mode--range-settings)
    (setq-local treesit-language-at-point-function
                #'vue-ts-mode--treesit-language-at-point)
    (treesit-major-mode-setup)))

(if (treesit-ready-p 'vue)
    (add-to-list 'auto-mode-alist '("\\.vue\\'" . vue-ts-mode)))

(advice-add
 #'treesit-buffer-root-node
 :before-while
 #'vue-ts-mode--advice-for-treesit-buffer-root-node)

(advice-add
 #'treesit--merge-ranges
 :before-while
 #'vue-ts-mode--advice-for-treesit--merge-ranges)

(provide 'vue-ts-mode)
;;; vue-ts-mode.el ends here
