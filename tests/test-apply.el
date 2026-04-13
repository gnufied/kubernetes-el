;;; test-apply.el --- Tests for kubernetes-apply. -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(load-file "./tests/undercover-init.el")

(require 'buttercup)
(require 'kubernetes-apply)

(describe "kubernetes-apply"
  (describe "kubernetes-apply--build-flags"
    (it "returns args unchanged when no prefix arg"
      (let ((args '("--dry-run=client" "--server-side")))
        (expect (kubernetes-apply--build-flags nil args)
                :to-equal '("--dry-run=client" "--server-side"))))

    (it "does not prompt for kubeconfig when --kubeconfig already in args"
      (let ((args '("--kubeconfig=/some/path" "--dry-run=client")))
        (expect (kubernetes-apply--build-flags t args)
                :to-equal '("--kubeconfig=/some/path" "--dry-run=client"))))

    (it "prompts for kubeconfig when prefix arg and no --kubeconfig in args"
      (spy-on 'kubernetes-popups--read-existing-file :and-return-value "/home/user/.kube/config")
      (let ((result (kubernetes-apply--build-flags t '("--dry-run=client"))))
        (expect 'kubernetes-popups--read-existing-file :to-have-been-called)
        (expect result :to-equal '("--kubeconfig=/home/user/.kube/config" "--dry-run=client")))))

  (describe "kubernetes-apply--execute"
    (it "calls kubernetes-kubectl with apply and correct file path"
      (spy-on 'kubernetes-state :and-return-value nil)
      (spy-on 'kubernetes-kubectl--flags-from-state :and-return-value nil)
      (spy-on 'kubernetes-kubectl)
      (spy-on 'display-buffer :and-return-value (selected-window))
      (kubernetes-apply--execute "apply" "/tmp/test.yaml" nil nil)
      (expect 'kubernetes-kubectl :to-have-been-called)
      (let ((call-args (spy-calls-args-for 'kubernetes-kubectl 0)))
        (expect (nth 1 call-args) :to-equal '("apply" "-f" "/tmp/test.yaml"))))

    (it "calls kubernetes-kubectl with create and correct file path"
      (spy-on 'kubernetes-state :and-return-value nil)
      (spy-on 'kubernetes-kubectl--flags-from-state :and-return-value nil)
      (spy-on 'kubernetes-kubectl)
      (spy-on 'display-buffer :and-return-value (selected-window))
      (kubernetes-apply--execute "create" "/tmp/test.yaml" nil nil)
      (expect 'kubernetes-kubectl :to-have-been-called)
      (let ((call-args (spy-calls-args-for 'kubernetes-kubectl 0)))
        (expect (nth 1 call-args) :to-equal '("create" "-f" "/tmp/test.yaml"))))))
