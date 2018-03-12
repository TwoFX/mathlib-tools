/-
Copyright (c) 2017 Johannes Hölzl. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Johannes Hölzl

Measure spaces -- measures

Measures are restricted to a measurable space (associated by the type class `measurable_space`).
This allows us to prove equalities between measures by restricting to a generating set of the
measurable space.

On the other hand, the `μ.measure s` projection (i.e. the measure of `s` on the measure space `μ`)
is the _outer_ measure generated by `μ`. This gives us a unrestricted monotonicity rule and it is
somehow well-behaved on non-measurable sets.

This allows us for the `lebesgue` measure space to have the `borel` measurable space, but still be
a complete measure.
-/
import data.set order.galois_connection analysis.ennreal
       analysis.measure_theory.outer_measure

noncomputable theory

open classical set lattice filter finset function
local attribute [instance] prop_decidable

universes u v w x

namespace measure_theory

structure measure_space (α : Type*) [m : measurable_space α] :=
(measure_of       : Π(s : set α), is_measurable s → ennreal)
(measure_of_empty : measure_of ∅ is_measurable_empty = 0)
(measure_of_Union :
  ∀{f:ℕ → set α}, ∀h : ∀i, is_measurable (f i), pairwise (disjoint on f) →
  measure_of (⋃i, f i) (is_measurable_Union h) = (∑i, measure_of (f i) (h i)))

namespace measure_space
variables {α : Type*} [measurable_space α] (μ : measure_space α) {s s₁ s₂ : set α}

/-- Measure projection which is ∞ for non-measurable sets.

`measure'` is mainly used to derive the outer measure, for the main `measure` projection. -/
protected def measure' (s : set α) : ennreal := ⨅ h : is_measurable s, μ.measure_of s h

protected lemma measure'_eq (h : is_measurable s) : μ.measure' s = μ.measure_of s h :=
by simp [measure_space.measure', h]

protected lemma measure'_empty : μ.measure' ∅ = 0 :=
by simp [μ.measure'_eq, measure_space.measure_of_empty, is_measurable_empty]

protected lemma measure'_Union {f : ℕ → set α}
  (hd : pairwise (disjoint on f)) (hm : ∀i, is_measurable (f i)) :
  μ.measure' (⋃i, f i) = (∑i, μ.measure' (f i)) :=
by simp [μ.measure'_eq, hm, is_measurable_Union hm] {contextual := tt};
from μ.measure_of_Union _ hd

protected lemma measure'_union {s₁ s₂ : set α}
  (hd : disjoint s₁ s₂) (h₁ : is_measurable s₁) (h₂ : is_measurable s₂) :
  μ.measure' (s₁ ∪ s₂) = μ.measure' s₁ + μ.measure' s₂ :=
let s := λn:ℕ, ([s₁, s₂].nth n).get_or_else ∅ in
have s0 : s 0 = s₁, from rfl,
have s1 : s 1 = s₂, from rfl,
have hd : pairwise (disjoint on s),
  from assume i j h,
  match i, j, h with
  | 0, 0, h := (h rfl).elim
  | 0, (nat.succ 0), h := hd
  | (nat.succ 0), 0, h := show s₂ ⊓ s₁ = ⊥, by rw [inf_comm]; assumption
  | (nat.succ 0), (nat.succ 0), h := (h rfl).elim
  | (nat.succ (nat.succ i)), j, h :=
    begin simp [s, disjoint, (on), option.get_or_else]; exact set.empty_inter _ end
  | i, (nat.succ (nat.succ j)), h :=
    begin simp [s, disjoint, (on), option.get_or_else]; exact set.inter_empty _ end
  end,
have Un_s : (⋃n, s n) = s₁ ∪ s₂,
  from subset.antisymm
    (Union_subset $ assume n, match n with
    | 0 := subset_union_left _ _
    | 1 := subset_union_right _ _
    | (nat.succ (nat.succ i)) := empty_subset _
    end)
    (union_subset (subset_Union s 0) (subset_Union s 1)),
have hms : ∀n, is_measurable (s n),
  from assume n, match n with
  | 0 := h₁
  | 1 := h₂
  | (nat.succ (nat.succ i)) := is_measurable_empty
  end,
calc μ.measure' (s₁ ∪ s₂) = μ.measure' (⋃n, s n) : by rw [Un_s]
  ... = (∑n, μ.measure' (s n)) :
    measure_space.measure'_Union μ hd hms
  ... = (range (nat.succ (nat.succ 0))).sum (λn, μ.measure' (s n)) :
    tsum_eq_sum $ assume n hn,
    match n, hn with
    | 0,                     h := by simp at h; contradiction
    | nat.succ 0,            h := by simp at h; contradiction
    | nat.succ (nat.succ n), h := μ.measure'_empty
    end
  ... = μ.measure' s₁ + μ.measure' s₂ :
    by simp [sum_insert, s0, s1]

protected lemma measure'_mono (h₁ : is_measurable s₁) (h₂ : is_measurable s₂) (hs : s₁ ⊆ s₂) :
  μ.measure' s₁ ≤ μ.measure' s₂ :=
have hd : s₁ ∩ (s₂ \ s₁) = ∅, from set.ext $ by simp [mem_sdiff] {contextual:=tt},
have hu : s₁ ∪ (s₂ \ s₁) = s₂,
  from set.ext $ assume x, by by_cases x ∈ s₁; simp [mem_sdiff, h, @hs x] {contextual:=tt},
calc μ.measure' s₁ ≤ μ.measure' s₁ + μ.measure' (s₂ \ s₁) :
    le_add_of_nonneg_right' ennreal.zero_le
  ... = μ.measure' (s₁ ∪ (s₂ \ s₁)) :
    (μ.measure'_union hd h₁ (is_measurable_sdiff h₂ h₁)).symm
  ... = μ.measure' s₂ :
    by simp [hu]

protected lemma measure'_Union_le_tsum_nat {s : ℕ → set α} (h : ∀i, is_measurable (s i)) :
  μ.measure' (⋃i, s i) ≤ (∑i, μ.measure' (s i)) :=
calc μ.measure' (⋃i, s i) = μ.measure' (⋃i, disjointed s i) :
    by simp [disjointed_Union]
  ... = ∑i, μ.measure' (disjointed s i) :
    μ.measure'_Union disjoint_disjointed $ assume i, is_measurable_disjointed h
  ... ≤ ∑i, μ.measure' (s i) :
    ennreal.tsum_le_tsum $ assume i,
      μ.measure'_mono (is_measurable_disjointed h) (h i) (inter_subset_left _ _)

/-- outer measure of a measure -/
protected def to_outer_measure : outer_measure α :=
outer_measure.of_function μ.measure' μ.measure'_empty

/-- Measure projections for a measure space.

For measurable sets this returns the measure assigned by the `measure_of` field in `measure_space`.
But we can extend this to _all_ sets, but using the outer measure. This gives us monotonicity and
subadditivity for all sets.
-/
protected def measure (s : set α) : ennreal := μ.to_outer_measure.measure_of s

protected lemma measure_eq (hs : is_measurable s) : μ.measure s = μ.measure_of s hs :=
le_antisymm
  (infi_le_of_le (λn, ⋃h : n = 0, s) $
    infi_le_of_le begin simp [set.subset_def] end $
    calc (∑i, ⨅ h : is_measurable (⋃ h : i = 0, s), μ.measure_of _ h) =
          ({0}:finset ℕ).sum (λi, ⨅ h : is_measurable (⋃ h : i = 0, s), μ.measure_of _ h) :
        tsum_eq_sum $ assume b,
          begin
            simp,
            intro hb,
            rw [set.Union_neg hb, infi_pos is_measurable_empty, measure_space.measure_of_empty]
          end
      ... ≤ μ.measure_of s hs : by simp [hs])
  (le_infi $ assume f, le_infi $ assume hf,
    classical.by_cases
      (assume : ∀i, is_measurable (f i),
        calc μ.measure_of s hs = μ.measure' s : by rw [μ.measure'_eq]
          ... ≤ μ.measure' (⋃i, f i) : μ.measure'_mono hs (is_measurable_Union this) hf
          ... ≤ ∑ (i : ℕ), μ.measure' (f i) : μ.measure'_Union_le_tsum_nat this)
      (assume : ¬ ∀i, is_measurable (f i),
        have ∃i, ¬ is_measurable (f i), by rwa [classical.not_forall] at this,
        let ⟨i, hi⟩ := this in
        calc μ.measure_of s hs ≤ μ.measure' (f i) : le_infi $ assume hi', by contradiction
          ... ≤ ∑ (i : ℕ), μ.measure' (f i) : ennreal.le_tsum))

protected lemma measure_eq_measure' (hs : is_measurable s) : μ.measure s = μ.measure' s :=
by rwa [μ.measure_eq, μ.measure'_eq]

end measure_space

section
variables {α : Type*} {β : Type*} [measurable_space α] {μ μ₁ μ₂ : measure_space α} {s s₁ s₂ : set α}

lemma measure_space_eq_of : ∀{μ₁ μ₂ : measure_space α},
  (∀s, ∀h:is_measurable s, μ₁.measure_of s h = μ₂.measure_of s h) → μ₁ = μ₂
| ⟨m₁, e₁, u₁⟩ ⟨m₂, e₂, u₂⟩ h :=
  have m₁ = m₂, from funext $ assume s, funext $ assume hs, h s hs,
  by simp [this]

lemma measure_space_eq (h : ∀s, is_measurable s → μ₁.measure s = μ₂.measure s) : μ₁ = μ₂ :=
measure_space_eq_of $ assume s hs,
  have μ₁.measure s = μ₂.measure s, from h s hs,
  by simp [measure_space.measure_eq, hs] at this; assumption

@[simp] lemma measure_empty : μ.measure ∅ = 0 := μ.to_outer_measure.empty

lemma measure_mono (h : s₁ ⊆ s₂) : μ.measure s₁ ≤ μ.measure s₂ := μ.to_outer_measure.mono h

lemma measure_Union_le_tsum_nat {s : ℕ → set α} : μ.measure (⋃i, s i) ≤ (∑i, μ.measure (s i)) :=
μ.to_outer_measure.Union_nat s

lemma measure_union (hd : disjoint s₁ s₂) (h₁ : is_measurable s₁) (h₂ : is_measurable s₂) :
  μ.measure (s₁ ∪ s₂) = μ.measure s₁ + μ.measure s₂ :=
by simp only [μ.measure_eq_measure', h₁, h₂, is_measurable_union];
from μ.measure'_union hd h₁ h₂

lemma measure_Union_nat {f : ℕ → set α}
  (hn : pairwise (disjoint on f)) (h : ∀i, is_measurable (f i)) :
  μ.measure (⋃i, f i) = (∑i, μ.measure (f i)) :=
by simp [measure_space.measure_eq, h, is_measurable_Union h, μ.measure_of_Union h hn]

lemma measure_bUnion {i : set β} {s : β → set α} (hi : countable i)
  (hd : pairwise_on i (disjoint on s)) (h : ∀b∈i, is_measurable (s b)) :
  μ.measure (⋃b∈i, s b) = ∑p:{b // b ∈ i}, μ.measure (s p.val) :=
let ⟨f, hf⟩ := hi in
let g : ℕ → set α := λn, ⋃b (h : b ∈ i) (h : f b = n), s b in
have h_gf : ∀b∈i, g (f b) = s b,
  from assume b hb, le_antisymm
    (supr_le $ assume b', supr_le $ assume hb', supr_le $ assume hbn,
      have f b = f b', by simp [hbn],
      have b = b', from hf _ hb _ hb' this,
      by simp [this]; exact le_refl _)
    (le_supr_of_le b $ le_supr_of_le hb $ le_supr_of_le rfl $ le_refl _),
have eq₁ : (⋃b∈i, s b) = (⋃i, g i),
  from le_antisymm
    (bUnion_subset $ assume b hb, show s b ≤ ⨆n (b:β) (h : b ∈ i) (h : f b = n), s b,
      from le_supr_of_le (f b) $ le_supr_of_le b $ le_supr_of_le hb $ le_supr_of_le rfl $ le_refl (s b))
    (supr_le $ assume n, supr_le $ assume b, supr_le $ assume hb, supr_le $ assume hnb,
      subset_bUnion_of_mem hb),
have hd : pairwise (disjoint on g),
  from assume n m h,
  set.eq_empty_of_subset_empty $ calc g n ∩ g m =
      (⋃b (h : b ∈ i) (h : f b = n) b' (h : b' ∈ i) (h : f b' = m), s b ∩ s b') :
        by simp [g, inter_distrib_Union_left, inter_distrib_Union_right]
      ... ⊆ ∅ :
        bUnion_subset $ assume b hb, Union_subset $ assume hbn,
        bUnion_subset $ assume b' hb', Union_subset $ assume hbm,
        have b ≠ b',
          from assume h_eq,
          have f b = f b', from congr_arg f h_eq,
          by simp [hbm, hbn, h] at this; assumption,
        have s b ∩ s b' = ∅,
          from hd b hb b' hb' this,
        by rw [this]; exact subset.refl _,
have hm : ∀n, is_measurable (g n),
  from assume n,
  by_cases
    (assume : ∃b∈i, f b = n, let ⟨b, hb, h_eq⟩ := this in
      have s b = g n, from h_eq ▸ (h_gf b hb).symm,
      this ▸ h b hb)
    (assume : ¬ ∃b∈i, f b = n,
      have g n = ∅, from set.eq_empty_of_subset_empty $
        bUnion_subset $ assume b hb, Union_subset $ assume h_eq, (this ⟨b, hb, h_eq⟩).elim,
      this.symm ▸ is_measurable_empty),
calc μ.measure (⋃b∈i, s b) = μ.measure (⋃i, g i) : by rw [eq₁]
  ... = (∑i, μ.measure (g i)) : measure_Union_nat hd hm
  ... = (∑p:{b // b ∈ i}, μ.measure (s p.val)) : tsum_eq_tsum_of_ne_zero_bij
    (λb h, f b.val)
    (assume ⟨b₁, hb₁⟩ ⟨b₂, hb₂⟩ _ _ h, subtype.eq $ show b₁ = b₂, from hf b₁ hb₁ b₂ hb₂ h)
    (assume n hn,
      have g n ≠ ∅, from assume h, by simp [h] at hn; assumption,
      have ∃b∈i, f b = n,
        from let ⟨x, hx⟩ := set.exists_mem_of_ne_empty this in
        by simp at hx; exact let ⟨b, hb, h_eq, _⟩ := hx in ⟨b, hb, h_eq⟩,
      let ⟨b, hb, h_eq⟩ := this in
      have g n = s b,
        from h_eq ▸ h_gf b hb,
      ⟨⟨b, hb⟩, by simp [this] at hn; assumption, h_eq⟩)
    (assume ⟨b, hb⟩, by simp [hb, h_gf])

lemma measure_sUnion [encodable β] {s : β → set α}
  (hd : pairwise (disjoint on s)) (h : ∀b, is_measurable (s b)) :
  μ.measure (⋃b, s b) = ∑b, μ.measure (s b) :=
calc μ.measure (⋃b, s b) = μ.measure (⋃b∈(univ:set β), s b) :
    congr_arg μ.measure $ set.ext $ by simp
  ... = ∑p:{b:β // true}, μ.measure (s p.val) :
    measure_bUnion countable_encodable (assume i _ j _, hd i j) (assume b _, h b)
  ... = ∑b, μ.measure (s b) : @tsum_eq_tsum_of_iso _ _ _ _ _ _ _ (λb, μ.measure (s b)) subtype.val
    (λb, ⟨b, trivial⟩ : β → {b:β // true}) (λ⟨b, hb⟩, rfl) (λb, rfl)

lemma measure_sdiff {s₁ s₂ : set α} (h : s₂ ⊆ s₁) (h₁ : is_measurable s₁) (h₂ : is_measurable s₂)
  (h_fin : μ.measure s₁ < ⊤) : μ.measure (s₁ \ s₂) = μ.measure s₁ - μ.measure s₂ :=
have hd : disjoint (s₁ \ s₂) s₂, from sdiff_inter_same,
have μ.measure s₂ < ⊤, from lt_of_le_of_lt (measure_mono h) h_fin,
calc μ.measure (s₁ \ s₂) = (μ.measure (s₁ \ s₂) + μ.measure s₂) - μ.measure s₂ :
    by rw [ennreal.add_sub_self this]
  ... = μ.measure (s₁ \ s₂ ∪ s₂) - μ.measure s₂ :
    by rw [measure_union hd]; simp [is_measurable_sdiff, h₁, h₂]
  ... = _ : by rw [sdiff_union_same, union_of_subset_right h]

lemma measure_Union_eq_supr_nat {s : ℕ → set α} (h : ∀i, is_measurable (s i)) (hs : monotone s) :
  μ.measure (⋃i, s i) = (⨆i, μ.measure (s i)) :=
-- TODO: generalize and extract from this proof
have ∀i, (range (i + 1)).sum (λi, μ.measure (disjointed s i)) = μ.measure (s i),
begin
  intro i, induction i,
  case nat.zero { simp [disjointed, nat.not_lt_zero, inter_univ] },
  case nat.succ : i ih {
    rw [range_succ, sum_insert, ih, ←measure_union],
    { show μ.measure (disjointed s (i + 1) ∪ s i) = μ.measure (s (i + 1)),
      rw [disjointed_of_mono hs, sdiff_union_same, union_of_subset_right],
      exact hs (nat.le_succ _) },
    { show disjoint (disjointed s (i + 1)) (s i),
      simp [disjoint, disjointed_of_mono hs],
      exact sdiff_inter_same },
    { exact is_measurable_disjointed h },
    { exact h _ },
    { exact not_mem_range_self } }
end,
calc μ.measure (⋃i, s i) = μ.measure (⋃i, disjointed s i) :
    by rw [disjointed_Union]
  ... = (∑i, μ.measure (disjointed s i)) :
    measure_Union_nat (disjoint_disjointed) (assume i, is_measurable_disjointed h)
  ... = (⨆i, (finset.range i).sum (λi, μ.measure (disjointed s i))) :
    by rw [ennreal.tsum_eq_supr_nat]
  ... = (⨆i, (range (i + 1)).sum (λi, μ.measure (disjointed s i))) :
    le_antisymm
      (supr_le begin intro i, cases i with j, simp, exact le_supr_of_le j (le_refl _) end)
      (supr_le $ assume i, le_supr_of_le (i + 1) $ le_refl _)
  ... = (⨆i, μ.measure (s i)) :
    congr_arg _ $ funext $ this

lemma measure_Inter_eq_infi_nat {s : ℕ → set α}
  (h : ∀i, is_measurable (s i)) (hs : ∀i j, i ≤ j → s j ⊆ s i) (hfin : μ.measure (s 0) < ⊤) :
  μ.measure (⋂i, s i) = (⨅i, μ.measure (s i)) :=
have eq₁ : (⋂i, s i) = (s 0 \ (⋃i, s 0 \ s i)),
  from set.ext $ begin simp [iff_def], simp [imp_false] {contextual := tt} end,
have sub : (⋃i, s 0 \ s i) ⊆ s 0,
  from Union_subset $ assume i, assume x, by simp {contextual := tt},
have hd : ∀i, is_measurable (s 0 \ s i), from assume i, is_measurable_sdiff (h 0) (h i),
have hu : is_measurable (⋃i, s 0 \ s i), from is_measurable_Union hd,
have hm : monotone (λ (i : ℕ), s 0 \ s i),
  from assume i j h, sdiff_subset_sdiff (subset.refl _) (hs i j h),
have eq₂ : ∀i, μ.measure (s 0) - (μ.measure (s 0) - μ.measure (s i)) = μ.measure (s i),
  from assume i,
  have μ.measure (s i) ≤ μ.measure (s 0), from measure_mono (hs _ _ $ nat.zero_le _),
  let ⟨r, hr, eqr, _⟩ := ennreal.lt_iff_exists_of_real.mp hfin in
  let ⟨p, hp, eqp, _⟩ := ennreal.lt_iff_exists_of_real.mp (lt_of_le_of_lt this hfin) in
  have 0 ≤ r - p,
    by rw [le_sub_iff_add_le, zero_add, ←ennreal.of_real_le_of_real_iff hp hr, ←eqp, ←eqr];
    from this,
  by simp [eqr, eqp, hp, hr, this, -sub_eq_add_neg, sub_sub_self],
calc μ.measure (⋂i, s i) = μ.measure (s 0 \ (⋃i, s 0 \ s i)) :
    congr_arg _ eq₁
  ... = μ.measure (s 0) - μ.measure (⋃i, s 0 \ s i) :
    by rw [measure_sdiff sub (h 0) hu hfin]
  ... = μ.measure (s 0) - (⨆i, μ.measure (s 0 \ s i)) :
    by rw [measure_Union_eq_supr_nat hd hm]
  ... = (⨅i, μ.measure (s 0) - μ.measure (s 0 \ s i)) :
    ennreal.sub_supr hfin
  ... = (⨅i, μ.measure (s i)) :
    congr_arg _ $ funext $ assume i,
      by rw [measure_sdiff (hs _ _ (nat.zero_le _)) (h 0) (h i) hfin, eq₂]

end

def outer_measure.to_measure
  {α : Type*} (m : outer_measure α) [ms : measurable_space α] (h : ms ≤ m.caratheodory) :
  measure_space α :=
{ measure_of       := λs hs, m.measure_of s,
  measure_of_empty := m.empty,
  measure_of_Union := assume s hs hf, m.Union_eq_of_caratheodory (assume i, h _ $ hs i) hf }

lemma le_to_outer_measure_caratheodory {α : Type*} [ms : measurable_space α] {μ : measure_space α} :
  ms ≤ μ.to_outer_measure.caratheodory :=
assume s hs, outer_measure.caratheodory_is_measurable $ assume t, by_cases
  (assume : is_measurable t,
    have hst₁ : is_measurable (t ∩ s), from is_measurable_inter this hs,
    have hst₂ : is_measurable (t \ s), from is_measurable_sdiff this hs,
    have t_eq : (t ∩ s) ∪ (t \ s) = t, from set.ext $ assume x, by by_cases x∈s; simp [h],
    have h : (t ∩ s) ∩ (t \ s) = ∅, from set.ext $ by simp {contextual:=tt},
    by rw [← μ.measure_eq_measure' this, ← μ.measure_eq_measure' hst₁, ← μ.measure_eq_measure' hst₂,
           ← measure_union h hst₁ hst₂, t_eq])
  (assume : ¬ is_measurable t, le_infi $ assume h, false.elim $ this h)

lemma to_outer_measure_to_measure {α : Type*} [ms : measurable_space α] {μ : measure_space α} :
  μ.to_outer_measure.to_measure le_to_outer_measure_caratheodory = μ :=
measure_space_eq $ assume s hs,
  by rw [μ.measure_eq hs, measure_space.measure_eq _ hs]; exact μ.measure_eq hs

namespace measure_space
variables {α : Type*} {β : Type*} {γ : Type*}
  [measurable_space α] [measurable_space β] [measurable_space γ]

instance : has_zero (measure_space α) :=
⟨{ measure_of := λs hs, 0, measure_of_empty := rfl, measure_of_Union := by simp }⟩

instance : inhabited (measure_space α) := ⟨0⟩

instance : has_add (measure_space α) :=
⟨λμ₁ μ₂, { measure_space .
  measure_of := λs hs, μ₁.measure_of s hs + μ₂.measure_of s hs,
  measure_of_empty := by simp [measure_space.measure_of_empty],
  measure_of_Union := assume f hf hd,
    by simp [measure_space.measure_of_Union, hf, hd, tsum_add] {contextual := tt} }⟩

instance : add_comm_monoid (measure_space α) :=
{ add_comm_monoid .
  zero      := 0,
  add       := (+),
  add_assoc := assume a b c, measure_space_eq_of $ assume s hs, add_assoc _ _ _,
  add_comm  := assume a b, measure_space_eq_of $ assume s hs, add_comm _ _,
  zero_add  := assume a, measure_space_eq_of $ assume s hs, zero_add _,
  add_zero  := assume a, measure_space_eq_of $ assume s hs, add_zero _ }

instance : partial_order (measure_space α) :=
{ partial_order .
  le          := λm₁ m₂, ∀s (hs : is_measurable s), m₁.measure_of s hs ≤ m₂.measure_of s hs,
  le_refl     := assume m s hs, le_refl _,
  le_trans    := assume m₁ m₂ m₃ h₁ h₂ s hs, le_trans (h₁ s hs) (h₂ s hs),
  le_antisymm := assume m₁ m₂ h₁ h₂, measure_space_eq_of $
    assume s hs, le_antisymm (h₁ s hs) (h₂ s hs) }

def map (f : α → β) (μ : measure_space α) : measure_space β :=
if hf : measurable f then
  { measure_of := λs hs, μ.measure (f ⁻¹' s),
    measure_of_empty := by simp,
    measure_of_Union := assume s hs h,
      have h' : pairwise (disjoint on λ (i : ℕ), f ⁻¹' s i),
        from assume i j hij,
        have s i ∩ s j = ∅, from h i j hij,
        show f ⁻¹' s i ∩ f ⁻¹' s j = ∅, by rw [← preimage_inter, this, preimage_empty],
      by rw [preimage_Union]; exact measure_Union_nat h' (assume i, hf (s i) (hs i)) }
else 0

variables {μ : measure_space α}

lemma map_measure {f : α → β} {s : set β} (hf : measurable f) (hs : is_measurable s) :
  (μ.map f).measure s = μ.measure (f ⁻¹' s) :=
by rw [map, dif_pos hf, measure_space.measure_eq _ hs]

lemma map_id : map id μ = μ :=
measure_space_eq $ assume s, map_measure measurable_id

lemma map_comp {f : α → β} {g : β → γ} (hf : measurable f) (hg : measurable g) :
  map (g ∘ f) μ = map g (map f μ) :=
measure_space_eq $ assume s hs,
  by rw [map_measure (measurable_comp hf hg) hs, map_measure hg hs, map_measure hf (hg s hs),
      preimage_comp]

/-- The dirac measure. -/
def dirac (a : α) : measure_space α :=
{ measure_of       := λs hs, ⨆h:a ∈ s, 1,
  measure_of_empty := by simp [ennreal.bot_eq_zero],
  measure_of_Union := assume f hf h, by_cases
    (assume : ∃i, a ∈ f i,
      let ⟨i, hi⟩ := this in
      have ∀j, (a ∈ f j) ↔ (i = j), from
        assume j, ⟨assume hj, classical.by_contradiction $ assume hij,
            have eq: f i ∩ f j = ∅, from h i j hij,
            have a ∈ f i ∩ f j, from ⟨hi, hj⟩,
            (mem_empty_eq a).mp $ by rwa [← eq],
          assume h, h ▸ hi⟩,
      by simp [this])
    (by simp [ennreal.bot_eq_zero] {contextual := tt}) }

/-- Sum of an indexed family of measures. -/
def sum {ι : Type*} (f : ι → measure_space α) : measure_space α :=
{ measure_of       := λs hs, ∑i, (f i).measure s,
  measure_of_empty := by simp,
  measure_of_Union := assume f hf h, by simp [measure_Union_nat h hf]; rw [ennreal.tsum_comm] }

/-- Counting measure on any measurable space. -/
def count : measure_space α := sum dirac

end measure_space

end measure_theory
