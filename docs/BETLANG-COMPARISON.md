<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
# StatistEase + BetLang Capability Comparison

```
┌─────────────────────────────┬──────────────────────┬──────────────────────┬──────────────┐
│ Capability                  │ BetLang (Racket)     │ StatistEase (Julia)  │ Winner       │
├─────────────────────────────┼──────────────────────┼──────────────────────┼──────────────┤
│ Descriptive stats           │ Basic (mean,med,mode)│ 13 measures + power  │ StatistEase  │
│ Hypothesis testing          │ Chi-sq, KS only      │ 15+ tests (MW,KW,   │ StatistEase  │
│                             │                      │ Fisher,MANOVA,etc)   │              │
│ Bayesian inference          │ MCMC,ABC,conjugate,  │ Bootstrap CI, EM     │ BetLang      │
│                             │ Bayes factors, HPD   │                      │              │
│ Sampling methods            │ 14 methods (HMC,SMC, │ Bootstrap only       │ BetLang      │
│                             │ slice,LHS,Sobol)     │                      │              │
│ Optimization                │ 13 algorithms (SA,GA,│ None                 │ BetLang      │
│                             │ PSO,DE,ant colony)   │                      │              │
│ Uncertainty types           │ 14 number systems    │ Tropical+p-adic+     │ BetLang      │
│                             │ (fuzzy,interval,etc) │ modular              │              │
│ Distributions               │ 20+ with sampling    │ 100+ via Distrib.jl  │ StatistEase  │
│ Markov chains / HMM         │ Full implementation  │ None                 │ BetLang      │
│ Financial risk              │ VaR,options,Dutch     │ None (before bridge) │ BetLang      │
│                             │ book,risk-of-ruin    │                      │              │
│ Nonparametric tests         │ None                 │ Full suite (midranks,│ StatistEase  │
│                             │                      │ ties,PERMANOVA)      │              │
│ Cross-verification          │ None                 │ Aspasia+ECHIDNA      │ StatistEase  │
│ Formal proofs               │ None                 │ 10 Agda proofs       │ StatistEase  │
│ Type safety                 │ 14 custom types      │ TypeLL L1-12         │ StatistEase  │
│ Game theory                 │ Nash,auctions,PD     │ None                 │ BetLang      │
│ Effect size classification  │ None                 │ Cohen d/r/η² auto    │ StatistEase  │
│ Multiple corrections        │ None                 │ Bonf/Holm/Sidak/FDR  │ StatistEase  │
├─────────────────────────────┼──────────────────────┼──────────────────────┼──────────────┤
│ INTEGRATION (bridge)        │ Julia backend 20%    │ betlang_bridge.jl    │ COMBINED     │
│                             │ BetLang.jl exists    │ 442 tests passing    │              │
└─────────────────────────────┴──────────────────────┴──────────────────────┴──────────────┘

COMBINED POWER: StatistEase uses BetLang for Bayesian/sampling/optimization/uncertainty.
BetLang uses StatistEase for hypothesis testing/formal verification/cross-verification.
```
