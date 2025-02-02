/-
Copyright (c) 2022 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
import Std.Logic
import Std.Data.RBMap.Basic

/-!
# Lemmas for Red-black trees

The main theorem in this file is `WF_def`, which shows that the `RBNode.WF.mk` constructor
subsumes the others, by showing that `insert` and `erase` satisfy the red-black invariants.
-/

namespace Std

namespace RBNode
open RBColor

theorem cmpLt.trans (h₁ : cmpLt cmp x y) (h₂ : cmpLt cmp y z) : cmpLt cmp x z :=
  ⟨TransCmp.lt_trans h₁.1 h₂.1⟩

theorem cmpLt.trans_l {cmp x y} (H : cmpLt cmp x y) {t : RBNode α}
    (h : t.All (cmpLt cmp y ·)) : t.All (cmpLt cmp x ·) := h.imp fun h => H.trans h

theorem cmpLt.trans_r {cmp x y} (H : cmpLt cmp x y) {a : RBNode α}
    (h : a.All (cmpLt cmp · x)) : a.All (cmpLt cmp · y) := h.imp fun h => h.trans H

/-- The `balance1` function preserves the ordering invariants. -/
protected theorem Ordered.balance1 {l : RBNode α} {v : α} {r : RBNode α}
    (lv : l.All (cmpLt cmp · v)) (vr : r.All (cmpLt cmp v ·))
    (hl : l.Ordered cmp) (hr : r.Ordered cmp) : (balance1 l v r).Ordered cmp := by
  unfold balance1; split
  case _ a x b y c =>
    have ⟨yv, _, cv⟩ := lv; have ⟨xy, yc, hx, hc⟩ := hl
    exact ⟨xy, ⟨yv, yc, yv.trans_l vr⟩, hx, cv, vr, hc, hr⟩
  case _ a x b y c _ =>
    have ⟨_, _, yv, _, cv⟩ := lv; have ⟨ax, ⟨xy, xb, _⟩, ha, by_, yc, hb, hc⟩ := hl
    exact ⟨⟨xy, xy.trans_r ax, by_⟩, ⟨yv, yc, yv.trans_l vr⟩, ⟨ax, xb, ha, hb⟩, cv, vr, hc, hr⟩
  case _ => exact ⟨lv, vr, hl, hr⟩

@[simp] theorem balance1_All {l : RBNode α} {v : α} {r : RBNode α} :
    (balance1 l v r).All p ↔ p v ∧ l.All p ∧ r.All p := by
  unfold balance1; split <;> simp [and_assoc, and_left_comm]

/-- The `balance2` function preserves the ordering invariants. -/
protected theorem Ordered.balance2 {l : RBNode α} {v : α} {r : RBNode α}
    (lv : l.All (cmpLt cmp · v)) (vr : r.All (cmpLt cmp v ·))
    (hl : l.Ordered cmp) (hr : r.Ordered cmp) : (balance2 l v r).Ordered cmp := by
  unfold balance2; split
  case _ b y c z d =>
    have ⟨_, ⟨vy, vb, _⟩, _⟩ := vr; have ⟨⟨yz, _, cz⟩, zd, ⟨by_, yc, hy, hz⟩, hd⟩ := hr
    exact ⟨⟨vy, vy.trans_r lv, by_⟩, ⟨yz, yc, yz.trans_l zd⟩, ⟨lv, vb, hl, hy⟩, cz, zd, hz, hd⟩
  case _ a x b y c _ =>
    have ⟨vx, va, _⟩ := vr; have ⟨ax, xy, ha, hy⟩ := hr
    exact ⟨⟨vx, vx.trans_r lv, ax⟩, xy, ⟨lv, va, hl, ha⟩, hy⟩
  case _ => exact ⟨lv, vr, hl, hr⟩

@[simp] theorem balance2_All {l : RBNode α} {v : α} {r : RBNode α} :
    (balance2 l v r).All p ↔ p v ∧ l.All p ∧ r.All p := by
  unfold balance2; split <;> simp [and_assoc, and_left_comm]

protected theorem All.ins {x : α} {t : RBNode α}
  (h₁ : p x) (h₂ : t.All p) : (ins cmp x t).All p := by
  induction t <;> unfold ins <;> simp [*] <;> split <;>
    cases ‹_=_› <;> split <;> simp at h₂ <;> simp [*]

/-- The `ins` function preserves the ordering invariants. -/
protected theorem Ordered.ins : ∀ {t : RBNode α}, t.Ordered cmp → (ins cmp x t).Ordered cmp
  | nil, _ => ⟨⟨⟩, ⟨⟩, ⟨⟩, ⟨⟩⟩
  | node red a y b, ⟨ay, yb, ha, hb⟩ => by
    unfold ins; split
    case _ h => exact ⟨ay.ins ⟨h⟩, yb, ha.ins, hb⟩
    case _ h => exact ⟨ay, yb.ins ⟨LawfulCmp.cmp_eq_gt.1 h⟩, ha, hb.ins⟩
    case _ h => exact (⟨
      ay.imp fun ⟨h'⟩ => ⟨(TransCmp.cmp_congr_right h).trans h'⟩,
      yb.imp fun ⟨h'⟩ => ⟨(TransCmp.cmp_congr_left h).trans h'⟩, ha, hb⟩)
  | node black a y b, ⟨ay, yb, ha, hb⟩ => by
    unfold ins; split
    case _ h => exact ha.ins.balance1 (ay.ins ⟨h⟩) yb hb
    case _ h => exact ha.balance2 ay (yb.ins ⟨LawfulCmp.cmp_eq_gt.1 h⟩) hb.ins
    case _ h => exact (⟨
      ay.imp fun ⟨h'⟩ => ⟨(TransCmp.cmp_congr_right h).trans h'⟩,
      yb.imp fun ⟨h'⟩ => ⟨(TransCmp.cmp_congr_left h).trans h'⟩, ha, hb⟩)

/-- The `insert` function preserves the ordering invariants. -/
protected theorem Ordered.insert (h : t.Ordered cmp) : (insert cmp t v).Ordered cmp := by
  unfold RBNode.insert cond; split <;> simp [Ordered.setBlack, h.ins (x := v)]

/--
The red-red invariant is a weakening of the red-black balance invariant which allows
the root to be red with red children, but does not allow any other violations.
It occurs as a temporary condition in the `insert` and `erase` functions.

The `p` parameter allows the `.redred` case to be dependent on an additional condition.
If it is false, then this is equivalent to the usual red-black invariant.
-/
inductive RedRed (p : Prop) : RBNode α → Nat → Prop where
  /-- A balanced tree has the red-red invariant. -/
  | balanced : Balanced t c n → RedRed p t n
  /-- A red node with balanced red children has the red-red invariant (if `p` is true). -/
  | redred : p → Balanced a c₁ n → Balanced b c₂ n → RedRed p (node red a x b) n

/-- When `p` is false, the red-red case is impossible so the tree is balanced. -/
protected theorem RedRed.of_false (h : ¬p) : RedRed p t n → ∃ c, Balanced t c n
  | .balanced h => ⟨_, h⟩
  | .redred hp .. => nomatch h hp

/-- A `red` node with the red-red invariant has balanced children. -/
protected theorem RedRed.of_red : RedRed p (node red a x b) n →
    ∃ c₁ c₂, Balanced a c₁ n ∧ Balanced b c₂ n
  | .balanced (.red ha hb) | .redred _ ha hb => ⟨_, _, ha, hb⟩

/-- The red-red invariant is monotonic in `p`. -/
protected theorem RedRed.imp (h : p → q) : RedRed p t n → RedRed q t n
  | .balanced h => .balanced h
  | .redred hp ha hb => .redred (h hp) ha hb

/-- If `t` has the red-red invariant, then setting the root to black yields a balanced tree. -/
protected theorem RedRed.setBlack : t.RedRed p n → ∃ n', (setBlack t).Balanced black n'
  | .balanced h => h.setBlack
  | .redred _ hl hr => ⟨_, hl.black hr⟩

/-- The `balance1` function repairs the balance invariant when the first argument is red-red. -/
protected theorem RedRed.balance1 {l : RBNode α} {v : α} {r : RBNode α}
    (hl : l.RedRed p n) (hr : r.Balanced c n) : ∃ c, (balance1 l v r).Balanced c (n + 1) := by
  unfold balance1; split
  · have .redred _ (.red ha hb) hc := hl; exact ⟨_, .red (.black ha hb) (.black hc hr)⟩
  · have .redred _ ha (.red hb hc) := hl; exact ⟨_, .red (.black ha hb) (.black hc hr)⟩
  case _ H1 H2 => match hl with
    | .balanced hl => exact ⟨_, .black hl hr⟩
    | .redred _ (c₁ := black) (c₂ := black) ha hb => exact ⟨_, .black (.red ha hb) hr⟩
    | .redred _ (c₁ := red) (.red ..) _ => cases H1 _ _ _ _ _ rfl
    | .redred _ (c₂ := red) _ (.red ..) => cases H2 _ _ _ _ _ rfl

/-- The `balance2` function repairs the balance invariant when the second argument is red-red. -/
protected theorem RedRed.balance2 {l : RBNode α} {v : α} {r : RBNode α}
    (hl : l.Balanced c n) (hr : r.RedRed p n) : ∃ c, (balance2 l v r).Balanced c (n + 1) := by
  unfold balance2; split
  · have .redred _ (.red ha hb) hc := hr; exact ⟨_, .red (.black hl ha) (.black hb hc)⟩
  · have .redred _ ha (.red hb hc) := hr; exact ⟨_, .red (.black hl ha) (.black hb hc)⟩
  case _ H1 H2 => match hr with
    | .balanced hr => exact ⟨_, .black hl hr⟩
    | .redred _ (c₁ := black) (c₂ := black) ha hb => exact ⟨_, .black hl (.red ha hb)⟩
    | .redred _ (c₁ := red) (.red ..) _ => cases H1 _ _ _ _ _ rfl
    | .redred _ (c₂ := red) _ (.red ..) => cases H2 _ _ _ _ _ rfl

/-! ## insert -/

/--
The balance invariant of the `ins` function.
The result of inserting into the tree either yields a balanced tree,
or a tree which is almost balanced except that it has a red-red violation at the root.
-/
protected theorem Balanced.ins (cmp v) {t : RBNode α}
    (h : t.Balanced c n) : (ins cmp v t).RedRed t.isRed n := by
  induction h with
  | nil => exact .balanced (.red .nil .nil)
  | @red a n b x hl hr ihl ihr =>
    unfold ins; split
    · match ins cmp v a, ihl with
      | _, .balanced .nil => exact .balanced (.red .nil hr)
      | _, .balanced (.red ha hb) => exact .redred rfl (.red ha hb) hr
      | _, .balanced (.black ha hb) => exact .balanced (.red (.black ha hb) hr)
      | _, .redred h .. => cases hl <;> cases h
    · match ins cmp v b, ihr with
      | _, .balanced .nil => exact .balanced (.red hl .nil)
      | _, .balanced (.red ha hb) => exact .redred rfl hl (.red ha hb)
      | _, .balanced (.black ha hb) => exact .balanced (.red hl (.black ha hb))
      | _, .redred h .. => cases hr <;> cases h
    · exact .balanced (.red hl hr)
  | @black a ca n b cb x hl hr ihl ihr =>
    unfold ins; split
    · exact have ⟨c, h⟩ := ihl.balance1 hr; .balanced h
    · exact have ⟨c, h⟩ := ihr.balance2 hl; .balanced h
    · exact .balanced (.black hl hr)

/--
The `insert` function is balanced if the input is balanced.
(We lose track of both the color and the black-height of the result,
so this is only suitable for use on the root of the tree.)
-/
theorem Balanced.insert {t : RBNode α} (h : t.Balanced c n) :
    ∃ c' n', (insert cmp t v).Balanced c' n' := by
  unfold insert cond; match ins cmp v t, h.ins cmp v with
  | _, .balanced h => split; {exact ⟨_, h.setBlack⟩}; {exact ⟨_, _, h⟩}
  | _, .redred h ha hb => have .node red .. := t; exact ⟨_, _, .black ha hb⟩

/-- The property of a cut function `cut` which ensures it can be used to find elements. -/
class IsCut (cmp : α → α → Ordering) (cut : α → Ordering) : Prop where
  /-- The set `{x | cut x = .lt}` is downward-closed. -/
  lt_trans : cmpLt cmp x y → cut x = .lt → cut y = .lt
  /-- The set `{x | cut x = .gt}` is upward-closed. -/
  gt_trans : cmpLt cmp x y → cut y = .gt → cut x = .gt

/-- A "representable cut" is one generated by `cmp a` for some `a`. This is always a valid cut. -/
instance (cmp) [TransCmp cmp] (a : α) : IsCut cmp (cmp a) where
  lt_trans h₁ h₂ := TransCmp.lt_trans h₂ h₁.1
  gt_trans h₁ h₂ := TransCmp.gt_trans h₂ (LawfulCmp.cmp_eq_gt.2 h₁.1)

protected theorem All.setRed {t : RBNode α} (h : t.All p) : (setRed t).All p := by
  unfold setRed; split <;> simp_all

/-- The `setRed` function preserves the ordering invariants. -/
protected theorem Ordered.setRed {t : RBNode α} : (setRed t).Ordered cmp ↔ t.Ordered cmp := by
  unfold setRed; split <;> simp [Ordered]

protected theorem All.balLeft
    (hl : l.All p) (hv : p v) (hr : r.All p) : (balLeft l v r).All p := by
  unfold balLeft; split <;> simp_all; split <;> simp_all [All.setRed]

/-- The `balLeft` function preserves the ordering invariants. -/
protected theorem Ordered.balLeft {l : RBNode α} {v : α} {r : RBNode α}
    (lv : l.All (cmpLt cmp · v)) (vr : r.All (cmpLt cmp v ·))
    (hl : l.Ordered cmp) (hr : r.Ordered cmp) : (balLeft l v r).Ordered cmp := by
  unfold balLeft; split
  · exact ⟨lv, vr, hl, hr⟩
  split
  · exact hl.balance2 lv vr hr
  · have ⟨vy, va, _⟩ := vr.2.1; have ⟨⟨yz, _, bz⟩, zc, ⟨ay, yb, ha, hb⟩, hc⟩ := hr
    exact ⟨⟨vy, vy.trans_r lv, ay⟩, balance2_All.2 ⟨yz, yb, (yz.trans_l zc).setRed⟩,
      ⟨lv, va, hl, ha⟩, hb.balance2 bz zc.setRed (Ordered.setRed.2 hc)⟩
  · exact ⟨lv, vr, hl, hr⟩

/-- The balancing properties of the `balLeft` function. -/
protected theorem Balanced.balLeft (hl : l.RedRed True n) (hr : r.Balanced cr (n + 1)) :
    (balLeft l v r).RedRed (cr = red) (n + 1) := by
  unfold balLeft; split
  case _ a x b => exact
    let ⟨ca, cb, ha, hb⟩ := hl.of_red
    match cr with
    | red => .redred rfl (.black ha hb) hr
    | black => .balanced (.red (.black ha hb) hr)
  case _ H => exact match hl with
    | .redred .. => nomatch H _ _ _ rfl
    | .balanced hl => match hr with
      | .black ha hb =>
        let ⟨c, h⟩ := RedRed.balance2 hl (.redred trivial ha hb); .balanced h
      | .red (.black ha hb) (.black hc hd) =>
        let ⟨c, h⟩ := RedRed.balance2 hb (.redred trivial hc hd); .redred rfl (.black hl ha) h

protected theorem All.balRight
    (hl : l.All p) (hv : p v) (hr : r.All p) : (balRight l v r).All p := by
  unfold balRight; split <;> simp_all; split <;> simp_all [All.setRed]

/-- The `balRight` function preserves the ordering invariants. -/
protected theorem Ordered.balRight {l : RBNode α} {v : α} {r : RBNode α}
    (lv : l.All (cmpLt cmp · v)) (vr : r.All (cmpLt cmp v ·))
    (hl : l.Ordered cmp) (hr : r.Ordered cmp) : (balRight l v r).Ordered cmp := by
  unfold balRight; split
  · exact ⟨lv, vr, hl, hr⟩
  split
  · exact hl.balance1 lv vr hr
  · have ⟨yv, _, cv⟩ := lv.2.2; have ⟨ax, ⟨xy, xb, _⟩, ha, by_, yc, hb, hc⟩ := hl
    exact ⟨balance1_All.2 ⟨xy, (xy.trans_r ax).setRed, by_⟩, ⟨yv, yc, yv.trans_l vr⟩,
      (Ordered.setRed.2 ha).balance1 ax.setRed xb hb, cv, vr, hc, hr⟩
  · exact ⟨lv, vr, hl, hr⟩

/-- The balancing properties of the `balRight` function. -/
protected theorem Balanced.balRight (hl : l.Balanced cl (n + 1)) (hr : r.RedRed True n) :
    (balRight l v r).RedRed (cl = red) (n + 1) := by
  unfold balRight; split
  case _ b y c => exact
    let ⟨cb, cc, hb, hc⟩ := hr.of_red
    match cl with
    | red => .redred rfl hl (.black hb hc)
    | black => .balanced (.red hl (.black hb hc))
  case _ H => exact match hr with
    | .redred .. => nomatch H _ _ _ rfl
    | .balanced hr => match hl with
      | .black hb hc =>
        let ⟨c, h⟩ := RedRed.balance1 (.redred trivial hb hc) hr; .balanced h
      | .red (.black ha hb) (.black hc hd) =>
        let ⟨c, h⟩ := RedRed.balance1 (.redred trivial ha hb) hc; .redred rfl h (.black hd hr)

protected theorem All.append (hl : l.All p) (hr : r.All p) : (append l r).All p := by
  unfold append; split <;> simp [*]
  · have ⟨hx, ha, hb⟩ := hl; have ⟨hy, hc, hd⟩ := hr
    have := hb.append hc; split <;> simp_all
  · have ⟨hx, ha, hb⟩ := hl; have ⟨hy, hc, hd⟩ := hr
    have := hb.append hc; split <;> simp_all [All.balLeft]
  · simp_all [hl.append hr.2.1]
  · simp_all [hl.2.2.append hr]
termination_by _ => l.size + r.size

/-- The `append` function preserves the ordering invariants. -/
protected theorem Ordered.append {l : RBNode α} {v : α} {r : RBNode α}
    (lv : l.All (cmpLt cmp · v)) (vr : r.All (cmpLt cmp v ·))
    (hl : l.Ordered cmp) (hr : r.Ordered cmp) : (append l r).Ordered cmp := by
  unfold append; split
  · exact hr
  · exact hl
  · have ⟨xv, _, bv⟩ := lv; have ⟨ax, xb, ha, hb⟩ := hl
    have ⟨vy, vc, _⟩ := vr; have ⟨cy, yd, hc, hd⟩ := hr
    have : _ ∧ _ ∧ _ := ⟨hb.append bv vc hc, xb.append (xv.trans_l vc), (vy.trans_r bv).append cy⟩
    split
    case _ H =>
      have ⟨⟨b'z, c'z, hb', hc'⟩, ⟨xz, xb', _⟩, zy, _, c'y⟩ := H ▸ this
      have az := xz.trans_r ax; have zd := zy.trans_l yd
      exact ⟨⟨xz, az, b'z⟩, ⟨zy, c'z, zd⟩, ⟨ax, xb', ha, hb'⟩, c'y, yd, hc', hd⟩
    · have ⟨hbc, xbc, bcy⟩ := this; have xy := xv.trans vy
      exact ⟨ax, ⟨xy, xbc, xy.trans_l yd⟩, ha, bcy, yd, hbc, hd⟩
  · have ⟨xv, _, bv⟩ := lv; have ⟨ax, xb, ha, hb⟩ := hl
    have ⟨vy, vc, _⟩ := vr; have ⟨cy, yd, hc, hd⟩ := hr
    have : _ ∧ _ ∧ _ := ⟨hb.append bv vc hc, xb.append (xv.trans_l vc), (vy.trans_r bv).append cy⟩
    split
    case _ H =>
      have ⟨⟨b'z, c'z, hb', hc'⟩, ⟨xz, xb', _⟩, zy, _, c'y⟩ := H ▸ this
      have az := xz.trans_r ax; have zd := zy.trans_l yd
      exact ⟨⟨xz, az, b'z⟩, ⟨zy, c'z, zd⟩, ⟨ax, xb', ha, hb'⟩, c'y, yd, hc', hd⟩
    · have ⟨hbc, xbc, bcy⟩ := this; have xy := xv.trans vy
      exact ha.balLeft ax ⟨xy, xbc, xy.trans_l yd⟩ ⟨bcy, yd, hbc, hd⟩
  · have ⟨vx, vb, _⟩ := vr; have ⟨bx, yc, hb, hc⟩ := hr
    exact ⟨(vx.trans_r lv).append bx, yc, hl.append lv vb hb, hc⟩
  · have ⟨xv, _, bv⟩ := lv; have ⟨ax, xb, ha, hb⟩ := hl
    exact ⟨ax, xb.append (xv.trans_l vr), ha, hb.append bv vr hr⟩
termination_by _ => l.size + r.size

/-- The balance properties of the `append` function. -/
protected theorem Balanced.append {l r : RBNode α}
    (hl : l.Balanced c₁ n) (hr : r.Balanced c₂ n) :
    (l.append r).RedRed (c₁ = black → c₂ ≠ black) n := by
  unfold append; split
  · exact .balanced hr
  · exact .balanced hl
  case _ b c _ _ =>
    have .red ha hb := hl; have .red hc hd := hr
    have ⟨_, IH⟩ := (hb.append hc).of_false (· rfl rfl); split
    case _ e =>
      have .red hb' hc' := e ▸ IH
      exact .redred (fun.) (.red ha hb') (.red hc' hd)
    case _ bcc _ H =>
      match bcc, append b c, IH, H with
      | black, _, IH, _ => exact .redred (fun.) ha (.red IH hd)
      | red, _, .red .., H => cases H _ _ _ rfl
  case _ b c _ _ =>
    have .black ha hb := hl; have .black hc hd := hr
    have IH := hb.append hc; split
    case _ e => match e ▸ IH with
      | .balanced (.red hb' hc') | .redred _ hb' hc' =>
        exact .balanced (.red (.black ha hb') (.black hc' hd))
    case _ H =>
      match append b c, IH, H with
      | bc, .balanced hbc, _ =>
        unfold balLeft; split
        · have .red ha' hb' := ha
          exact .balanced (.red (.black ha' hb') (.black hbc hd))
        · exact have ⟨c, h⟩ := RedRed.balance2 ha (.redred trivial hbc hd); .balanced h
      | _, .redred .., H => cases H _ _ _ rfl
  · have .red hc hd := hr; have IH := hl.append hc
    have .black ha hb := hl; have ⟨c, IH⟩ := IH.of_false (· rfl rfl)
    exact .redred (fun.) IH hd
  · have .red ha hb := hl; have IH := hb.append hr
    have .black hc hd := hr; have ⟨c, IH⟩ := IH.of_false (· rfl rfl)
    exact .redred (fun.) ha IH
termination_by _ => l.size + r.size

/-! ## erase -/

/--
The invariant of the `del` function.
* If the input tree is black, then the result of deletion is a red-red tree with
  black-height lowered by 1.
* If the input tree is red or nil, then the result of deletion is a balanced tree with
  some color and the same black-height.
-/
def DelProp (t₀ t : RBNode α) (n : Nat) : Prop :=
  bif t₀.isBlack then ∃ n', n = n' + 1 ∧ RedRed True t n' else ∃ c, Balanced t c n

/-- The `DelProp` property is a strengthened version of the red-red invariant. -/
theorem DelProp.redred (h : DelProp t₀ t n) : ∃ n', RedRed t₀.isBlack t n' := by
  unfold DelProp at h
  exact match t₀.isBlack, h with
  | false, ⟨_, h⟩ => ⟨_, .balanced h⟩
  | true, ⟨_, _, h⟩ => ⟨_, h.imp fun _ => rfl⟩

protected theorem All.del : ∀ {t : RBNode α}, t.All p → (del cut t).All p
  | .nil, h => h
  | .node .., ⟨hy, ha, hb⟩ => by
    unfold del; split
    · unfold cond; split
      · exact ha.del.balLeft hy hb
      · exact ⟨hy, ha.del, hb⟩
    · unfold cond; split
      · exact ha.balRight hy hb.del
      · exact ⟨hy, ha, hb.del⟩
    · exact ha.append hb

/-- The `del` function preserves the ordering invariants. -/
protected theorem Ordered.del : ∀ {t : RBNode α}, t.Ordered cmp → (del cut t).Ordered cmp
  | .nil, _ => ⟨⟩
  | .node _ a y b, ⟨ay, yb, ha, hb⟩ => by
    unfold del; split
    · unfold cond; split
      · exact ha.del.balLeft ay.del yb hb
      · exact ⟨ay.del, yb, ha.del, hb⟩
    · unfold cond; split
      · exact ha.balRight ay yb.del hb.del
      · exact ⟨ay, yb.del, ha, hb.del⟩
    · exact ha.append ay yb hb

/-- The `del` function has the `DelProp` property. -/
protected theorem Balanced.del {t : RBNode α} (h : t.Balanced c n) : t.DelProp (t.del cut) n := by
  induction h with
  | nil => exact ⟨_, .nil⟩
  | @black a _ n b _ _ ha hb iha ihb =>
    refine ⟨_, rfl, ?_⟩
    unfold del; split
    · exact match a, n, iha with
      | .nil, _, ⟨c, ha⟩ | .node red .., _, ⟨c, ha⟩ => .redred ⟨⟩ ha hb
      | .node black .., _, ⟨n, rfl, ha⟩ => (hb.balLeft ha).imp fun _ => ⟨⟩
    · exact match b, n, ihb with
      | .nil, _, ⟨c, hb⟩ | .node .red .., _, ⟨c, hb⟩ => .redred ⟨⟩ ha hb
      | .node black .., _, ⟨n, rfl, hb⟩ => (ha.balRight hb).imp fun _ => ⟨⟩
    · exact (ha.append hb).imp fun _ => ⟨⟩
  | @red a n b _ ha hb iha ihb =>
    unfold del; split
    · exact match a, n, iha with
      | .nil, _, _ => ⟨_, .red ha hb⟩
      | .node black .., _, ⟨n, rfl, ha⟩ => (hb.balLeft ha).of_false (fun.)
    · exact match b, n, ihb with
      | .nil, _, _ => ⟨_, .red ha hb⟩
      | .node black .., _, ⟨n, rfl, hb⟩ => (ha.balRight hb).of_false (fun.)
    · exact (ha.append hb).of_false (· rfl rfl)

/-- The `erase` function preserves the ordering invariants. -/
protected theorem Ordered.erase {t : RBNode α} (h : t.Ordered cmp) : (erase cut t).Ordered cmp :=
  Ordered.setBlack.2 h.del

/-- The `erase` function preserves the balance invariants. -/
protected theorem Balanced.erase {t : RBNode α}
    (h : t.Balanced c n) : ∃ n, (t.erase cut).Balanced black n :=
  have ⟨_, h⟩ := h.del.redred; h.setBlack

/--
The well-formedness invariant for a red-black tree is exactly the `mk` constructor,
because the other constructors of `WF` are redundant.
-/
@[simp] theorem WF_def {t : RBNode α} : t.WF cmp ↔ t.Ordered cmp ∧ ∃ c n, t.Balanced c n := by
  refine ⟨fun h => ?_, fun ⟨o, _, _, h⟩ => .mk o h⟩
  induction h with
  | mk o h => exact ⟨o, _, _, h⟩
  | insert _ ih => have ⟨o, _, _, h⟩ := ih; exact ⟨o.insert, h.insert⟩
  | erase _ ih => have ⟨o, _, _, h⟩ := ih; exact ⟨o.erase, _, h.erase⟩
