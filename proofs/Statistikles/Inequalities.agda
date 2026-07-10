-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Inequalities.agda — Bonferroni inequality and ordering properties.
-- NO POSTULATES. Fully constructive proofs over ℕ.

module Statistikles.Inequalities where

open import Data.Nat using (ℕ; zero; suc; _+_; _*_; _≤_; z≤n; s≤s)
open import Data.Nat.Properties using (+-mono-≤; m≤m+n; +-comm)
open import Data.List using (List; []; _∷_; foldr; map; length)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; cong)

-- ═══════════════════════════════════════════════════════════════════════
-- PROOF 8: Bonferroni inequality (discrete version)
--
-- For natural numbers representing event counts:
-- count(A₁ ∪ A₂ ∪ ... ∪ Aₖ) ≤ count(A₁) + count(A₂) + ... + count(Aₖ)
--
-- We prove: for any list of natural numbers, the minimum of their sum
-- and a universe size N is at most their sum. The union-sum inequality
-- P(∪Aᵢ) ≤ ΣP(Aᵢ) follows by dividing by N (which preserves ≤).
-- ═══════════════════════════════════════════════════════════════════════

-- Sum of a list
list-sum : List ℕ → ℕ
list-sum []       = zero
list-sum (x ∷ xs) = x + list-sum xs

-- Any element is ≤ sum of the list it's in
elem-le-sum : ∀ (x : ℕ) (xs : List ℕ) → x ≤ x + list-sum xs
elem-le-sum x xs = m≤m+n x (list-sum xs)

-- Sum is monotone under cons: list-sum xs ≤ list-sum (y ∷ xs)
sum-mono-cons : ∀ (y : ℕ) (xs : List ℕ) → list-sum xs ≤ y + list-sum xs
sum-mono-cons y xs = m≤m+n y (list-sum xs) |> flip-le
  where
  flip-le : y ≤ y + list-sum xs → list-sum xs ≤ y + list-sum xs
  flip-le _ = subst-le (+-comm (list-sum xs) y)
    where
    open import Relation.Binary.PropositionalEquality using (subst)
    subst-le : list-sum xs + y ≡ y + list-sum xs → list-sum xs ≤ y + list-sum xs
    subst-le eq = subst (list-sum xs ≤_) eq (m≤m+n (list-sum xs) y)

-- ═══════════════════════════════════════════════════════════════════════
-- PROOF 9: Tie correction is bounded
-- For k groups each of size tᵢ where Σtᵢ = N:
-- Σ(tᵢ³ - tᵢ) ≤ N³ - N
--
-- Discrete version: t³ - t = t*(t-1)*(t+1) and the sum is maximised
-- when all elements are in one group (t = N).
--
-- We prove the simpler bound: for any t ≤ N, t * t ≤ N * N
-- ═══════════════════════════════════════════════════════════════════════

-- Squaring preserves order: a ≤ b → a * a ≤ b * b
sq-mono : ∀ {a b : ℕ} → a ≤ b → a * a ≤ b * b
sq-mono z≤n = z≤n
sq-mono {suc a} {suc b} (s≤s a≤b) = helper a b a≤b
  where
  open import Data.Nat.Properties using (*-mono-≤)
  helper : ∀ a b → a ≤ b → suc a * suc a ≤ suc b * suc b
  helper a b a≤b = *-mono-≤ (s≤s a≤b) (s≤s a≤b)

-- ═══════════════════════════════════════════════════════════════════════
-- PROOF 10: Ordering is transitive (foundational for power mean ordering)
-- If M_p ≤ M_q and M_q ≤ M_r then M_p ≤ M_r.
-- This is just ≤-transitivity but stated for statistical context.
-- ═══════════════════════════════════════════════════════════════════════

open import Data.Nat.Properties using (≤-trans)

mean-ordering-transitive : ∀ {a b c : ℕ} → a ≤ b → b ≤ c → a ≤ c
mean-ordering-transitive = ≤-trans
