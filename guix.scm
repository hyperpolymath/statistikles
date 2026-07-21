;; SPDX-License-Identifier: MPL-2.0
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
;;
;; Guix package definition for Statistikles.
;;
;; Usage:
;;   guix build -f guix.scm       # Build the package
;;   guix shell -D -f guix.scm    # Enter a development shell (julia on PATH)
;;
;; --------------------------------------------------------------------------
;; Build strategy (and its honest limits) — READ THIS.
;; --------------------------------------------------------------------------
;; Statistikles is a Julia *application* whose dependency closure (CSV,
;; DataFrames, Distributions, HTTP, JSON3, StatsBase, ...) is pinned in the
;; committed Manifest.toml. Guix builds run inside a network-isolated sandbox,
;; and not every one of those Julia packages exists in Guix at the exact pinned
;; version, so we deliberately do NOT try to `Pkg.instantiate()` the full
;; closure during the build — that would require network access the sandbox
;; forbids, or a hand-maintained fork of ~a dozen `julia-*' Guix packages kept
;; in lockstep with Manifest.toml. Neither is honest to promise here.
;;
;; Therefore this package uses `copy-build-system' to install the source tree
;; (src/, Project.toml, Manifest.toml, README.adoc) plus a `bin/statistikles'
;; launcher, and its `check' phase runs a real, offline integrity check:
;; it parses Project.toml and Manifest.toml with Julia's bundled TOML stdlib
;; and runs `Pkg.status()' against the pinned project. That verifies the
;; manifests are well-formed and internally consistent — it does NOT compile
;; the Julia sources or exercise the statistics (that needs the instantiated
;; depot). The launcher documents the one-time `Pkg.instantiate()' a user runs
;; against a writable JULIA_DEPOT_PATH to populate the closure from the
;; committed Manifest.toml before first use.
;;
;; In short: this builds and installs a runnable, self-documenting Julia
;; project + launcher and verifies manifest integrity offline; it is not a
;; from-source recompilation of the whole Julia dependency graph. Upgrading to
;; the latter (via `julia-build-system' once all deps are in Guix at the pinned
;; versions) is tracked as future work.

(use-modules (guix packages)
             (guix gexp)
             (guix build-system copy)
             ((guix licenses) #:prefix license:)
             (gnu packages bash)
             (gnu packages julia))

(package
  (name "statistikles")
  (version "0.1.0")
  (source (local-file "." "statistikles-checkout"
                      #:recursive? #t
                      #:select? (lambda (file stat)
                                  (not (string-contains file ".git")))))
  (build-system copy-build-system)
  (arguments
   (list
    #:install-plan
    #~'(("src" "share/statistikles/src")
        ("Project.toml" "share/statistikles/Project.toml")
        ("Manifest.toml" "share/statistikles/Manifest.toml")
        ("README.adoc" "share/doc/statistikles/README.adoc"))
    #:phases
    #~(modify-phases %standard-phases
        ;; Real, offline integrity check: the manifests must parse and be
        ;; internally consistent. Forced offline so nothing touches the network.
        (add-after 'unpack 'check-manifest-integrity
          (lambda _
            (setenv "HOME" (getcwd))
            (setenv "JULIA_DEPOT_PATH"
                    (string-append (getcwd) "/.guix-julia-depot"))
            (setenv "JULIA_PKG_OFFLINE" "true")
            (invoke #$(file-append julia "/bin/julia")
                    "--project=." "--startup-file=no" "--color=no"
                    "-e"
                    (string-append
                     "using TOML;"
                     "TOML.parsefile(\"Project.toml\");"
                     "TOML.parsefile(\"Manifest.toml\");"
                     "using Pkg; Pkg.status();"
                     "println(\"integrity ok: Project.toml + Manifest.toml"
                     " parse and resolve\")"))))
        ;; Install a launcher that runs the project with the store-resident
        ;; Julia. The dependency closure must be instantiated once into a
        ;; writable depot (see the emitted comment) before first use.
        (add-after 'install 'install-launcher
          (lambda* (#:key outputs #:allow-other-keys)
            (let* ((out (assoc-ref outputs "out"))
                   (bin (string-append out "/bin"))
                   (proj (string-append out "/share/statistikles"))
                   (launcher (string-append bin "/statistikles")))
              (mkdir-p bin)
              (call-with-output-file launcher
                (lambda (port)
                  (format port "#!~a/bin/bash~%" #$bash-minimal)
                  (format port "# Statistikles launcher (installed by guix.scm).~%")
                  (format port "# One-time setup: instantiate the pinned closure~%")
                  (format port "# into a writable depot, e.g.~%")
                  (format port "#   JULIA_DEPOT_PATH=\"$HOME/.julia\" \\~%")
                  (format port "#     ~a/bin/julia --project=~a \\~%"
                          #$julia proj)
                  (format port "#     -e 'using Pkg; Pkg.instantiate()'~%")
                  (format port "exec ~a/bin/julia --project=~a \\~%"
                          #$julia proj)
                  (format port "  -e 'using Statistikles; main()' \"$@\"~%")))
              (chmod launcher #o555)))))))
  (inputs (list bash-minimal julia))
  (home-page "https://github.com/hyperpolymath/statistikles")
  (synopsis "Neurosymbolic statistical analysis assistant (Julia computes, LLM routes)")
  (description
   "Statistikles is a Kautz Type 3 neurosymbolic statistical analysis
assistant.  A neural component (an LLM) understands a question posed in natural
language, routes it to the correct statistical function, and explains the
result in plain English; a symbolic component (Julia) performs @emph{all}
mathematical computation.  Every statistical value is produced by a verified,
deterministic Julia function, never by neural inference, so the tool cannot
fabricate means, p-values, or confidence intervals.  It ships roughly forty
statistics modules spanning descriptive, inferential, correlation and
regression, non-parametric, effect-size, power, Bayesian, fuzzy-logic,
Dempster-Shafer, reliability, validity, and measurement analyses.")
  (license license:mpl2.0))
