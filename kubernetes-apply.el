;;; kubernetes-apply.el --- Support for applying Kubernetes manifests  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'transient)

(require 'kubernetes-core)
(require 'kubernetes-kubectl)
(require 'kubernetes-modes)
(require 'kubernetes-popups)
(require 'kubernetes-state)
(require 'kubernetes-vars)

(defvar kubernetes-apply-history nil
  "History list for manifest file paths.")

(defun kubernetes-apply--read-manifest-file ()
  "Read a Kubernetes manifest file path from the user."
  (read-file-name "Manifest file: " nil nil t nil
                  (lambda (f)
                    (or (file-directory-p f)
                        (string-match-p "\\.\\(ya?ml\\|json\\)\\'" f)))))

(defun kubernetes-apply--build-flags (prefix-arg args)
  "Build extra flags for kubectl apply/create.
If PREFIX-ARG is non-nil and no --kubeconfig is in ARGS,
prompt for a kubeconfig file path."
  (let ((flags (copy-sequence args)))
    (when (and prefix-arg
               (not (seq-find (lambda (a) (string-prefix-p "--kubeconfig=" a)) flags)))
      (let ((kubeconfig (kubernetes-popups--read-existing-file "Kubeconfig file: ")))
        (push (format "--kubeconfig=%s" kubeconfig) flags)))
    flags))

(defun kubernetes-apply--execute (operation file-path args prefix-arg)
  "Execute kubectl OPERATION (-f FILE-PATH) with ARGS.
PREFIX-ARG controls whether to prompt for KUBECONFIG."
  (let* ((state (kubernetes-state))
         (extra-flags (kubernetes-apply--build-flags prefix-arg
                        (seq-filter (lambda (a) (string-prefix-p "--" a)) args)))
         (all-flags (append (kubernetes-kubectl--flags-from-state state) extra-flags))
         (expanded-path (expand-file-name file-path))
         (display-name (file-name-nondirectory file-path))
         (buffer-name (format "*kubernetes %s: %s*" operation display-name))
         (buf (get-buffer-create buffer-name)))
    (with-current-buffer buf
      (kubernetes-display-thing-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "Running kubectl %s -f %s..." operation display-name)
                            'face 'kubernetes-dimmed))))
    (kubernetes-kubectl state
                        (list operation "-f" expanded-path)
                        (lambda (response-buf)
                          (let ((output (with-current-buffer response-buf (buffer-string))))
                            (with-current-buffer buf
                              (let ((inhibit-read-only t))
                                (erase-buffer)
                                (insert (format "kubectl %s -f %s\n\n" operation display-name))
                                (insert output)
                                (goto-char (point-min))))
                            (kubernetes--info "Successfully ran kubectl %s on %s" operation display-name)))
                        (lambda (err-buf)
                          (let ((err-output (with-current-buffer err-buf (buffer-string))))
                            (with-current-buffer buf
                              (let ((inhibit-read-only t))
                                (erase-buffer)
                                (insert (propertize (format "Error running kubectl %s -f %s:\n\n"
                                                            operation display-name)
                                                    'face 'error))
                                (insert err-output)
                                (goto-char (point-min))))
                            (kubernetes--error "Failed to %s %s" operation display-name)))
                        nil
                        :flags all-flags)
    (select-window (display-buffer buf))
    buf))

;;;###autoload
(defun kubernetes-apply-file (file-path args prefix-arg)
  "Apply a Kubernetes manifest FILE-PATH using kubectl apply.
ARGS are additional transient arguments.
With PREFIX-ARG (\\[universal-argument]), prompt for an explicit KUBECONFIG file path."
  (interactive
   (let ((prefix current-prefix-arg))
     (list (kubernetes-apply--read-manifest-file)
           (transient-args 'kubernetes-apply)
           prefix)))
  (kubernetes-apply--execute "apply" file-path args prefix-arg))

;;;###autoload
(defun kubernetes-create-file (file-path args prefix-arg)
  "Create Kubernetes resources from manifest FILE-PATH using kubectl create.
ARGS are additional transient arguments.
With PREFIX-ARG (\\[universal-argument]), prompt for an explicit KUBECONFIG file path."
  (interactive
   (let ((prefix current-prefix-arg))
     (list (kubernetes-apply--read-manifest-file)
           (transient-args 'kubernetes-apply)
           prefix)))
  (kubernetes-apply--execute "create" file-path args prefix-arg))

;;;###autoload
(defun kubernetes-apply-buffer (prefix-arg)
  "Apply the current buffer's file as a Kubernetes manifest.
With PREFIX-ARG (\\[universal-argument]), prompt for an explicit KUBECONFIG file path."
  (interactive "P")
  (let ((file (buffer-file-name)))
    (unless file
      (user-error "Buffer is not visiting a file"))
    (unless (string-match-p "\\.\\(ya?ml\\|json\\)\\'" file)
      (unless (y-or-n-p (format "File %s doesn't look like a manifest. Apply anyway? "
                                (file-name-nondirectory file)))
        (user-error "Aborted")))
    (when (buffer-modified-p)
      (when (y-or-n-p "Buffer has unsaved changes. Save first? ")
        (save-buffer)))
    (kubernetes-apply-file file nil prefix-arg)))

(transient-define-prefix kubernetes-apply ()
  "Apply or create Kubernetes resources from manifest files."
  [["Options"
    ("=k" "Kubeconfig" "--kubeconfig=" kubernetes-popups--read-existing-file)
    ("-n" "Namespace" "--namespace=" read-string)
    ("-l" "Selector" "--selector=" read-string)]
   ["Apply Flags"
    ("-f" "Force conflicts" "--force-conflicts")
    ("-s" "Server-side apply" "--server-side")
    ("-d" "Dry run" "--dry-run=client")]]
  [["Actions"
    ("a" "Apply file" kubernetes-apply-file)
    ("c" "Create file" kubernetes-create-file)
    ("b" "Apply current buffer" kubernetes-apply-buffer)]])

(provide 'kubernetes-apply)

;;; kubernetes-apply.el ends here
