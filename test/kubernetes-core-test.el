;;; kubernetes-core-test.el --- Tests for kubernetes-core.el  -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'kubernetes-core)

(ert-deftest kubernetes-core-test--update-section-highlight-skips-when-no-section ()
  (let (called)
    (cl-letf (((symbol-function 'magit-current-section) (lambda () nil))
              ((symbol-function 'magit-region-sections) (lambda () nil))
              ((symbol-function 'magit-section-update-highlight)
               (lambda (&optional _force)
                 (setq called t))))
      (kubernetes--update-section-highlight)
      (should-not called))))

(ert-deftest kubernetes-core-test--update-section-highlight-runs-at-point ()
  (let (called)
    (cl-letf (((symbol-function 'magit-current-section) (lambda () t))
              ((symbol-function 'magit-region-sections) (lambda () nil))
              ((symbol-function 'magit-section-update-highlight)
               (lambda (&optional force)
                 (setq called force))))
      (kubernetes--update-section-highlight t)
      (should called))))

(ert-deftest kubernetes-core-test--update-section-highlight-runs-for-region ()
  (let (called)
    (cl-letf (((symbol-function 'magit-current-section) (lambda () nil))
              ((symbol-function 'magit-region-sections) (lambda () '(section)))
              ((symbol-function 'magit-section-update-highlight)
               (lambda (&optional _force)
                 (setq called t))))
      (kubernetes--update-section-highlight)
      (should called))))

(provide 'kubernetes-core-test)

;;; kubernetes-core-test.el ends here
