<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Statistikles + BetLang Capability Comparison

```
┌─────────────────────────────┬──────────────────────┬──────────────────────┬──────────────┐
│ Capability                  │ BetLang (Racket)     │ Statistikles (Julia)  │ Winner       │
├─────────────────────────────┼──────────────────────┼──────────────────────┼──────────────┤
│ Descriptive stats           │ Basic (mean,med,mode)│ 13 measures + power  │ Statistikles  │
│ Hypothesis testing          │ Chi-sq, KS only      │ 15+ tests (MW,KW,   │ Statistikles  │
│                             │                      │ Fisher,MANOVA,etc)   │              │
│ Bayesian inference          │ MCMC,ABC,conjugate,  │ Bootstrap CI, EM     │ BetLang      │
│                             │ Bayes factors, HPD   │                      │              │
│ Sampling methods            │ 14 methods (HMC,SMC, │ Bootstrap only       │ BetLang      │
│                             │ slice,LHS,Sobol)     │                      │              │
│ Optimization                │ 13 algorithms (SA,GA,│ None                 │ BetLang      │
│                             │ PSO,DE,ant colony)   │                      │              │
│ Uncertainty types           │ 14 number systems    │ Tropical+p-adic+     │ BetLang      │
│                             │ (fuzzy,interval,etc) │ modular              │              │
│ Distributions               │ 20+ with sampling    │ 100+ via Distrib.jl  │ Statistikles  │
│ Markov chains / HMM         │ Full implementation  │ None                 │ BetLang      │
│ Financial risk              │ VaR,options,Dutch     │ None (before bridge) │ BetLang      │
│                             │ book,risk-of-ruin    │                      │              │
│ Nonparametric tests         │ None                 │ Full suite (midranks,│ Statistikles  │
│                             │                      │ ties,PERMANOVA)      │              │
│ Cross-verification          │ None                 │ Aspasia+ECHIDNA      │ Statistikles  │
│ Formal proofs               │ None                 │ 10 Agda proofs       │ Statistikles  │
│ Type safety                 │ 14 custom types      │ TypeLL L1-12         │ Statistikles  │
│ Game theory                 │ Nash,auctions,PD     │ None                 │ BetLang      │
│ Effect size classification  │ None                 │ Cohen d/r/η² auto    │ Statistikles  │
│ Multiple corrections        │ None                 │ Bonf/Holm/Sidak/FDR  │ Statistikles  │
├─────────────────────────────┼──────────────────────┼──────────────────────┼──────────────┤
│ INTEGRATION (bridge)        │ Julia backend 20%    │ betlang_bridge.jl    │ COMBINED     │
│                             │ BetLang.jl exists    │ 442 tests passing    │              │
└─────────────────────────────┴──────────────────────┴──────────────────────┴──────────────┘

COMBINED POWER: Statistikles uses BetLang for Bayesian/sampling/optimization/uncertainty.
BetLang uses Statistikles for hypothesis testing/formal verification/cross-verification.
```
