/-
Copyright (c) 2017 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura, Mario Carneiro
-/
import Std.Classes.Order

/-!
# Red-black trees

This module implements a type `RBMap α β cmp` which is a functional data structure for
storing a key-value store in a binary search tree.

It is built on the simpler `RBSet α cmp` type, which stores a set of values of type `α`
using the function `cmp : α → α → Ordering` for determining the ordering relation.
The tree will never store two elements that compare `.eq` under the `cmp` function,
but the function does not have to satisfy `cmp x y = .eq → x = y`, and in the map case
`α` is a key-value pair and the `cmp` function only compares the keys.
-/

namespace Std

/--
In a red-black tree, every node has a color which is either "red" or "black"
(this particular choice of colors is conventional). A nil node is considered black.
-/
inductive RBColor where
  /-- A red node is required to have black children. -/
  | red
  /-- Every path from the root to a leaf must pass through the same number of black nodes. -/
  | black

/--
A red-black tree. (This is an internal implementation detail of the `RBSet` type,
which includes the invariants of the tree.) This is a binary search tree augmented with
a "color" field which is either red or black for each node and used to implement
the re-balancing operations.
See: [Red–black tree](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree)
-/
inductive RBNode (α : Type u) where
  /-- An empty tree. -/
  | nil
  /-- A node consists of a value `v`, a subtree `l` of smaller items,
  and a subtree `r` of larger items. The color `c` is either `red` or `black`
  and participates in the red-black balance invariant (see `Balanced`). -/
  | node (c : RBColor) (l : RBNode α) (v : α) (r : RBNode α)

namespace RBNode
open RBColor

/-- The minimum element of a tree is the left-most value. -/
protected def min : RBNode α → Option α
  | nil            => none
  | node _ nil v _ => some v
  | node _ l _ _   => l.min

/-- The maximum element of a tree is the right-most value. -/
protected def max : RBNode α → Option α
  | nil            => none
  | node _ _ v nil => some v
  | node _ _ _ r   => r.max

/--
Fold a function in tree order along the nodes. `v₀` is used at `nil` nodes and
`f` is used to combine results at branching nodes.
-/
@[specialize] def fold (v₀ : σ) (f : σ → α → σ → σ) : RBNode α → σ
  | nil          => v₀
  | node _ l v r => f (l.fold v₀ f) v (r.fold v₀ f)

/-- Fold a function on the values from left to right (in increasing order). -/
@[specialize] def foldl (f : σ → α → σ) : (init : σ) → RBNode α → σ
  | b, nil          => b
  | b, node _ l v r => foldl f (f (foldl f b l) v) r

/-- Run monadic function `f` on each element of the tree (in increasing order). -/
@[specialize] def forM [Monad m] (f : α → m Unit) : RBNode α → m Unit
  | nil          => pure ()
  | node _ l v r => do forM f l; f v; forM f r

/-- Fold a monadic function on the values from left to right (in increasing order). -/
@[specialize] def foldlM [Monad m] (f : σ → α → m σ) : (init : σ) → RBNode α → m σ
  | b, nil          => pure b
  | b, node _ l v r => do foldlM f (← f (← foldlM f b l) v) r

/-- Implementation of `for x in t` loops over a `RBNode` (in increasing order). -/
@[inline] protected def forIn [Monad m]
    (as : RBNode α) (init : σ) (f : α → σ → m (ForInStep σ)) : m σ := do
  match ← visit as init with
  | .done b  => pure b
  | .yield b => pure b
where
  /-- Inner loop of `forIn`. -/
  @[specialize] visit : RBNode α → σ → m (ForInStep σ)
    | nil,          b => return ForInStep.yield b
    | node _ l v r, b => do
      match ← visit l b with
      | r@(.done _) => return r
      | .yield b    =>
        match ← f v b with
        | r@(.done _) => return r
        | .yield b    => visit r b

/-- Fold a function on the values from right to left (in decreasing order). -/
@[specialize] def foldr (f : α → σ → σ) : RBNode α → (init : σ) → σ
  | nil,          b => b
  | node _ l v r, b => l.foldr f (f v (r.foldr f b))

/-- Returns `true` iff every element of the tree satisfies `p`. -/
@[specialize] def all (p : α → Bool) : RBNode α → Bool
  | nil          => true
  | node _ l v r => p v && all p l && all p r

/-- Returns `true` iff any element of the tree satisfies `p`. -/
@[specialize] def any (p : α → Bool) : RBNode α → Bool
  | nil          => false
  | node _ l v r => p v || any p l || any p r

/-- Asserts that `p` holds on every element of the tree. -/
@[simp] def All (p : α → Prop) : RBNode α → Prop
  | nil          => True
  | node _ l v r => p v ∧ All p l ∧ All p r

theorem All.imp (H : ∀ {x : α}, p x → q x) : ∀ {t : RBNode α}, t.All p → t.All q
  | nil => id
  | node .. => fun ⟨h, hl, hr⟩ => ⟨H h, hl.imp H, hr.imp H⟩

/-- Asserts that `p` holds on some element of the tree. -/
@[simp] def Any (p : α → Prop) : RBNode α → Prop
  | nil          => False
  | node _ l v r => p v ∨ Any p l ∨ Any p r

/--
The red-black balance invariant. `Balanced t c n` says that the color of the root node is `c`,
and the black-height (the number of black nodes on any path from the root) of the tree is `n`.
Additionally, every red node must have black children.
-/
inductive Balanced : RBNode α → RBColor → Nat → Prop where
  /-- A nil node is balanced with black-height 0, and it is considered black. -/
  | protected nil : Balanced nil black 0
  /-- A red node is balanced with black-height `n`
  if its children are both black with with black-height `n`. -/
  | protected red : Balanced x black n → Balanced y black n → Balanced (node red x v y) red n
  /-- A black node is balanced with black-height `n + 1`
  if its children both have black-height `n`. -/
  | protected black : Balanced x c₁ n → Balanced y c₂ n → Balanced (node black x v y) black (n + 1)

/--
We say that `x < y` under the comparator `cmp` if `cmp x y = .lt`.

* In order to avoid assuming the comparator is always lawful, we use a
  local `∀ [TransCmp cmp]` binder in the relation so that the ordering
  properties of the tree only need to hold if the comparator is lawful.
* The `Nonempty` wrapper is a no-op because this is already a proposition,
  but it prevents the `[TransCmp cmp]` binder from being introduced when we don't want it.
-/
def cmpLt (cmp : α → α → Ordering) (x y : α) : Prop := Nonempty (∀ [TransCmp cmp], cmp x y = .lt)

/--
The ordering invariant of a red-black tree, which is a binary search tree.
This says that every element of a left subtree is less than the root, and
every element in the right subtree is greater than the root, where the
less than relation `x < y` is understood to mean `cmp x y = .lt`.

Because we do not assume that `cmp` is lawful when stating this property,
we write it in such a way that if `cmp` is not lawful then the condition holds trivially.
That way we can prove the ordering invariants without assuming `cmp` is lawful.
-/
def Ordered (cmp : α → α → Ordering) : RBNode α → Prop
  | nil => True
  | node _ a x b => a.All (cmpLt cmp · x) ∧ b.All (cmpLt cmp x ·) ∧ a.Ordered cmp ∧ b.Ordered cmp

/-- The first half of Okasaki's `balance`, concerning red-red sequences in the left child. -/
@[inline] def balance1 : RBNode α → α → RBNode α → RBNode α
  | node red (node red a x b) y c, z, d
  | node red a x (node red b y c), z, d => node red (node black a x b) y (node black c z d)
  | a,                             x, b => node black a x b

/-- The second half of Okasaki's `balance`, concerning red-red sequences in the right child. -/
@[inline] def balance2 : RBNode α → α → RBNode α → RBNode α
  | a, x, node red (node red b y c) z d
  | a, x, node red b y (node red c z d) => node red (node black a x b) y (node black c z d)
  | a, x, b                             => node black a x b

/-- An auxiliary function to test if the root is red. -/
def isRed : RBNode α → Bool
  | node red .. => true
  | _           => false

/-- An auxiliary function to test if the root is black (and non-nil). -/
def isBlack : RBNode α → Bool
  | node black .. => true
  | _             => false

/-- Change the color of the root to `black`. -/
def setBlack : RBNode α → RBNode α
  | nil          => nil
  | node _ l v r => node black l v r

protected theorem Ordered.setBlack {t : RBNode α} : (setBlack t).Ordered cmp ↔ t.Ordered cmp := by
  unfold setBlack; split <;> simp [Ordered]

protected theorem Balanced.setBlack : t.Balanced c n → ∃ n', (setBlack t).Balanced black n'
  | .nil => ⟨_, .nil⟩
  | .black hl hr | .red hl hr => ⟨_, hl.black hr⟩

section Insert

/--
The core of the `insert` function. This adds an element `x` to a balanced red-black tree.
Importantly, the result of calling `ins` is not a proper red-black tree,
because it has a broken balance invariant.
(See `Balanced.ins` for the balance invariant of `ins`.)
The `insert` function does the final fixup needed to restore the invariant.
-/
@[specialize] def ins (cmp : α → α → Ordering) (x : α) : RBNode α → RBNode α
  | nil => node red nil x nil
  | node red a y b =>
    match cmp x y with
    | Ordering.lt => node red (ins cmp x a) y b
    | Ordering.gt => node red a y (ins cmp x b)
    | Ordering.eq => node red a x b
  | node black a y b =>
    match cmp x y with
    | Ordering.lt => balance1 (ins cmp x a) y b
    | Ordering.gt => balance2 a y (ins cmp x b)
    | Ordering.eq => node black a x b

/--
`insert cmp t v` inserts element `v` into the tree, using the provided comparator
`cmp` to put it in the right place and automatically rebalancing the tree as necessary.
-/
@[specialize] def insert (cmp : α → α → Ordering) (t : RBNode α) (v : α) : RBNode α :=
  bif isRed t then (ins cmp v t).setBlack else ins cmp v t

end Insert

/-- Recolor the root of the tree to `red` if possible. -/
def setRed : RBNode α → RBNode α
  | node _ a v b => node red a v b
  | nil          => nil

/-- Rebalancing a tree which has shrunk on the left. -/
def balLeft (l : RBNode α) (v : α) (r : RBNode α) : RBNode α :=
  match l with
  | node red a x b                    => node red (node black a x b) v r
  | l => match r with
    | node black a y b                => balance2 l v (node red a y b)
    | node red (node black a y b) z c => node red (node black l v a) y (balance2 b z (setRed c))
    | r                               => node red l v r -- unreachable

/-- Rebalancing a tree which has shrunk on the right. -/
def balRight (l : RBNode α) (v : α) (r : RBNode α) : RBNode α :=
  match r with
  | node red b y c                    => node red l v (node black b y c)
  | r => match l with
    | node black a x b                => balance1 (node red a x b) v r
    | node red a x (node black b y c) => node red (balance1 (setRed a) x b) y (node black c v r)
    | l                               => node red l v r -- unreachable

/-- The number of nodes in the tree. -/
@[simp] def size : RBNode α → Nat
  | nil => 0
  | node _ x _ y => x.size + y.size + 1

/-- Concatenate two trees with the same black-height. -/
def append : RBNode α → RBNode α → RBNode α
  | nil, x | x, nil => x
  | node red a x b, node red c y d =>
    match append b c with
    | node red b' z c' => node red (node red a x b') z (node red c' y d)
    | bc               => node red a x (node red bc y d)
  | node black a x b, node black c y d =>
    match append b c with
    | node red b' z c' => node red (node black a x b') z (node black c' y d)
    | bc               => balLeft a x (node black bc y d)
  | a@(node black ..), node red b x c => node red (append a b) x c
  | node red a x b, c@(node black ..) => node red a x (append b c)
termination_by _ x y => x.size + y.size

/-! ## erase -/

/--
The core of the `erase` function. The tree returned from this function has a broken invariant,
which is restored in `erase`.
-/
@[specialize] def del (cut : α → Ordering) : RBNode α → RBNode α
  | nil          => nil
  | node _ a y b =>
    match cut y with
    | .lt => bif a.isBlack then balLeft (del cut a) y b else node red (del cut a) y b
    | .gt => bif b.isBlack then balRight a y (del cut b) else node red a y (del cut b)
    | .eq => append a b

/--
The `erase cut t` function removes an element from the tree `t`.
The `cut` function is used to locate an element in the tree:
it returns `.gt` if we go too high and `.lt` if we go too low;
if it returns `.eq` we will remove the element.
(The function `cmp k` for some key `k` is a valid cut function, but we can also use cuts that
are not of this form as long as they are suitably monotonic.)
-/
@[specialize] def erase (cut : α → Ordering) (t : RBNode α) : RBNode α := (del cut t).setBlack

section Membership

/-- Finds an element in the tree satisfying the `cut` function. -/
@[specialize] def find? (cut : α → Ordering) : RBNode α → Option α
  | nil => none
  | node _ a y b =>
    match cut y with
    | .lt => find? cut a
    | .gt => find? cut b
    | .eq => some y

/-- `lowerBound? cut` retrieves the largest entry smaller than or equal to `cut`, if it exists. -/
@[specialize] def lowerBound? (cut : α → Ordering) : RBNode α → Option α → Option α
  | nil,          lb => lb
  | node _ a y b, lb =>
    match cut y with
    | .lt => lowerBound? cut a lb
    | .gt => lowerBound? cut b (some y)
    | .eq => some y

end Membership

/-- Map a function on every value in the tree. This can break the order invariant  -/
@[specialize] def map (f : α → β) : RBNode α → RBNode β
  | nil => nil
  | node c l v r => node c (l.map f) (f v) (r.map f)

/-- Converts the tree into an array in increasing sorted order. -/
def toArray (n : RBNode α) : Array α := n.foldl (init := #[]) (·.push ·)

instance : EmptyCollection (RBNode α) := ⟨nil⟩

/--
The well-formedness invariant for a red-black tree. The first constructor is the real invariant,
and the others allow us to "cheat" in this file and define `insert` and `erase`,
which have more complex proofs that are delayed to `Std.Data.RBMap.Lemmas`.
-/
inductive WF (cmp : α → α → Ordering) : RBNode α → Prop
  /-- The actual well-formedness invariant: a red-black tree has the
  ordering and balance invariants. -/
  | mk : t.Ordered cmp → t.Balanced c n → WF cmp t
  /-- Inserting into a well-formed tree yields another well-formed tree.
  (See `Ordered.insert` and `Balanced.insert` for the actual proofs.) -/
  | insert : WF cmp t → WF cmp (t.insert cmp a)
  /-- Erasing from a well-formed tree yields another well-formed tree.
  (See `Ordered.erase` and `Balanced.erase` for the actual proofs.) -/
  | erase : WF cmp t → WF cmp (t.erase cut)

end RBNode

open RBNode

/--
An `RBSet` is a self-balancing binary search tree.
The `cmp` function is the comparator that will be used for performing searches;
it should satisfy the requirements of `TransCmp` for it to have sensible behavior.
-/
def RBSet (α : Type u) (cmp : α → α → Ordering) : Type u := {t : RBNode α // t.WF cmp}

/-- `O(1)`. Construct a new empty tree. -/
@[inline] def mkRBSet (α : Type u) (cmp : α → α → Ordering) : RBSet α cmp := ⟨.nil, .mk ⟨⟩ .nil⟩

namespace RBSet

/-- `O(1)`. Construct a new empty tree. -/
@[inline] def empty : RBSet α cmp := mkRBSet ..

instance (α : Type u) (cmp : α → α → Ordering) : EmptyCollection (RBSet α cmp) := ⟨empty⟩

instance (α : Type u) (cmp : α → α → Ordering) : Inhabited (RBSet α cmp) := ⟨∅⟩

/-- `O(1)`. Construct a new tree with one element `v`. -/
@[inline] def single (v : α) : RBSet α cmp :=
  ⟨.node .red .nil v .nil, .mk ⟨⟨⟩, ⟨⟩, ⟨⟩, ⟨⟩⟩ (.red .nil .nil)⟩

/-- `O(n)`. Fold a function on the values from left to right (in increasing order). -/
@[inline] def foldl (f : σ → α → σ) (init : σ) (t : RBSet α cmp) : σ := t.1.foldl f init

/-- `O(n)`. Fold a function on the values from right to left (in decreasing order). -/
@[inline] def foldr (f : α → σ → σ) (init : σ) (t : RBSet α cmp) : σ := t.1.foldr f init

/-- `O(n)`. Fold a monadic function on the values from left to right (in increasing order). -/
@[inline] def foldlM [Monad m] (f : σ → α → m σ) (init : σ) (t : RBSet α cmp) : m σ :=
  t.1.foldlM f init

/-- `O(n)`. Run monadic function `f` on each element of the tree (in increasing order). -/
@[inline] def forM [Monad m] (f : α → m PUnit) (t : RBSet α cmp) : m PUnit := t.1.forM f

instance : ForIn m (RBSet α cmp) α where
  forIn t init f := t.1.forIn init f

/-- `O(1)`. Is the tree empty? -/
@[inline] def isEmpty : RBSet α cmp → Bool
  | ⟨nil, _⟩ => true
  | _        => false

/-- `O(n)`. Convert the tree to a list in ascending order. -/
@[specialize] def toList (t : RBSet α cmp) : List α := t.1.foldr (·::·) []

/-- `O(log n)`. Returns the entry `a` such that `a ≤ k` for all keys in the RBSet. -/
@[inline] protected def min (t : RBSet α cmp) : Option α := t.1.min

/-- `O(log n)`. Returns the entry `a` such that `a ≥ k` for all keys in the RBSet. -/
@[inline] protected def max (t : RBSet α cmp) : Option α := t.1.max

instance [Repr α] : Repr (RBSet α cmp) where
  reprPrec m prec := Repr.addAppParen ("Std.rbmapOf " ++ repr m.toList) prec

/-- `O(log n)`. Insert element `v` into the tree. -/
@[inline] def insert (t : RBSet α cmp) (v : α) : RBSet α cmp := ⟨t.1.insert cmp v, t.2.insert⟩

/--
`O(log n)`. Remove an element from the tree using a cut function.
The `cut` function is used to locate an element in the tree:
it returns `.gt` if we go too high and `.lt` if we go too low;
if it returns `.eq` we will remove the element.
(The function `cmp k` for some key `k` is a valid cut function, but we can also use cuts that
are not of this form as long as they are suitably monotonic.)
-/
@[inline] def erase (t : RBSet α cmp) (cut : α → Ordering) : RBSet α cmp :=
  ⟨t.1.erase cut, t.2.erase⟩

/-- `O(log n)`. Find an element in the tree using a cut function. -/
@[inline] def findP? (t : RBSet α cmp) (cut : α → Ordering) : Option α := t.1.find? cut

/-- `O(log n)`. Returns an element in the tree equivalent to `x` if one exists. -/
@[inline] def find? (t : RBSet α cmp) (x : α) : Option α := t.1.find? (cmp x)

/-- `O(log n)`. Find an element in the tree, or return a default value `v₀`. -/
@[inline] def findPD (t : RBSet α cmp) (cut : α → Ordering) (v₀ : α) : α := (t.findP? cut).getD v₀

/--
`O(log n)`. `lowerBoundP cut` retrieves the largest entry comparing `lt` or `eq` under `cut`,
if it exists.
-/
@[inline] def lowerBoundP? (t : RBSet α cmp) (cut : α → Ordering) : Option α :=
  t.1.lowerBound? cut none

/--
`O(log n)`. `lowerBound? k` retrieves the largest entry smaller than or equal to `k`,
if it exists.
-/
@[inline] def lowerBound? (t : RBSet α cmp) (k : α) : Option α := t.1.lowerBound? (cmp k) none

/-- `O(log n)`. Returns true if the given cut returns `eq` for something in the RBSet. -/
@[inline] def containsP (t : RBSet α cmp) (cut : α → Ordering) : Bool := (t.findP? cut).isSome

/-- `O(log n)`. Returns true if the given key `a` is in the RBSet. -/
@[inline] def contains (t : RBSet α cmp) (a : α) : Bool := (t.find? a).isSome

/-- `O(n log n)`. Build a tree from an unsorted list by inserting them one at a time. -/
@[inline] def ofList (l : List α) (cmp : α → α → Ordering) : RBSet α cmp :=
  l.foldl (fun r p => r.insert p) (mkRBSet α cmp)

/-- `O(n log n)`. Build a tree from an unsorted array by inserting them one at a time. -/
@[inline] def ofArray (l : Array α) (cmp : α → α → Ordering) : RBSet α cmp :=
  l.foldl (fun r p => r.insert p) (mkRBSet α cmp)

/-- `O(n)`. Returns true if the given predicate is true for all items in the RBSet. -/
@[inline] def all (t : RBSet α cmp) (p : α → Bool) : Bool := t.1.all p

/-- `O(n)`. Returns true if the given predicate is true for any item in the RBSet. -/
@[inline] def any (t : RBSet α cmp) (p : α → Bool) : Bool := t.1.any p

/-- `O(n)`. The number of items in the RBSet. -/
def size (m : RBSet α cmp) : Nat := m.1.size

/-- `O(log n)`. Returns the minimum element of the tree, or panics if the tree is empty. -/
@[inline] def min! [Inhabited α] (t : RBSet α cmp) : α := t.min.getD (panic! "tree is empty")

/-- `O(log n)`. Returns the maximum element of the tree, or panics if the tree is empty. -/
@[inline] def max! [Inhabited α] (t : RBSet α cmp) : α := t.max.getD (panic! "tree is empty")

/--
`O(log n)`. Attempts to find the value with key `k : α` in `t` and panics if there is no such key.
-/
@[inline] def findP! [Inhabited α] (t : RBSet α cmp) (cut : α → Ordering) : α :=
  (t.findP? cut).getD (panic! "key is not in the tree")

/--
`O(log n)`. Attempts to find the value with key `k : α` in `t` and panics if there is no such key.
-/
@[inline] def find! [Inhabited α] (t : RBSet α cmp) (k : α) : α :=
  (t.find? k).getD (panic! "key is not in the tree")

/--
`O(n₂ * log (n₁ + n₂))`. Merges the maps `t₁` and `t₂`.
If equal keys exist in both, the key from `t₂` is preferred.
-/
def union (t₁ t₂ : RBSet α cmp) : RBSet α cmp :=
  t₂.foldl .insert t₁

/--
`O(n₂ * log (n₁ + n₂))`. Merges the maps `t₁` and `t₂`. If equal keys exist in both,
then use `mergeFn a₁ a₂` to produce the new merged value.
-/
def mergeBy (mergeFn : α → α → α) (t₁ t₂ : RBSet α cmp) : RBSet α cmp :=
  t₂.foldl (init := t₁) fun t₁ a₂ =>
    t₁.insert <| match t₁.find? a₂ with | some a₁ => mergeFn a₁ a₂ | none => a₂

/--
`O(n₁ * log (n₁ + n₂))`. Intersects the maps `t₁` and `t₂`
using `mergeFn a b` to produce the new value.
-/
def intersectBy (cmp : α → β → Ordering) (mergeFn : α → β → γ)
    (t₁ : RBSet α cmpα) (t₂ : RBSet β cmpβ) : RBSet γ cmpγ :=
  t₁.foldl (init := ∅) fun acc a =>
    match t₂.findP? (cmp a) with
    | some b => acc.insert <| mergeFn a b
    | none => acc

/-- `O(n * log n)`. Constructs the set of all elements satisfying `p`. -/
def filter (t : RBSet α cmp) (p : α → Bool) : RBSet α cmp :=
  t.foldl (init := ∅) fun acc a => bif p a then acc.insert a else acc

/--
`O(n₁ * (log n₁ + log n₂))`. Constructs the set of all elements of `t₁` that are not in `t₂`.
-/
def sdiff (t₁ t₂ : RBSet α cmp) : RBSet α cmp := t₁.filter (!t₂.contains ·)

end RBSet

/- TODO(Leo): define dRBMap -/

/--
An `RBSet` is a self-balancing binary search tree, used to store a key-value map.
The `cmp` function is the comparator that will be used for performing searches;
it should satisfy the requirements of `TransCmp` for it to have sensible behavior.
-/
def RBMap (α : Type u) (β : Type v) (cmp : α → α → Ordering) : Type (max u v) :=
  RBSet (α × β) (fun a b => cmp a.1 b.1)

/-- `O(1)`. Construct a new empty map. -/
@[inline] def mkRBMap (α : Type u) (β : Type v) (cmp : α → α → Ordering) : RBMap α β cmp :=
  mkRBSet ..

/-- `O(1)`. Construct a new empty map. -/
@[inline] def RBMap.empty {α : Type u} {β : Type v} {cmp : α → α → Ordering} : RBMap α β cmp :=
  mkRBMap ..

instance (α : Type u) (β : Type v) (cmp : α → α → Ordering) : EmptyCollection (RBMap α β cmp) :=
  ⟨RBMap.empty⟩

instance (α : Type u) (β : Type v) (cmp : α → α → Ordering) : Inhabited (RBMap α β cmp) := ⟨∅⟩

/-- `O(1)`. Construct a new tree with one key-value pair `k, v`. -/
@[inline] def single (k : α) (v : β) : RBMap α β cmp := RBSet.single (k, v)

namespace RBMap
variable {α : Type u} {β : Type v} {σ : Type w} {cmp : α → α → Ordering}

/-- `O(n)`. Fold a function on the values from left to right (in increasing order). -/
@[inline] def foldl (f : σ → α → β → σ) : (init : σ) → RBMap α β cmp → σ
  | b, ⟨t, _⟩ => t.foldl (fun s (a, b) => f s a b) b

/-- `O(n)`. Fold a function on the values from right to left (in decreasing order). -/
@[inline] def foldr (f : α → β → σ → σ) : (init : σ) → RBMap α β cmp → σ
  | b, ⟨t, _⟩ => t.foldr (fun (a, b) s => f a b s) b

/-- `O(n)`. Fold a monadic function on the values from left to right (in increasing order). -/
@[inline] def foldlM [Monad m] (f : σ → α → β → m σ) : (init : σ) → RBMap α β cmp → m σ
  | b, ⟨t, _⟩ => t.foldlM (fun s (a, b) => f s a b) b

/-- `O(n)`. Run monadic function `f` on each element of the tree (in increasing order). -/
@[inline] def forM [Monad m] (f : α → β → m PUnit) (t : RBMap α β cmp) : m PUnit :=
  t.foldlM (fun _ k v => f k v) ⟨⟩

instance : ForIn m (RBMap α β cmp) (α × β) where
  forIn t init f := t.val.forIn init f

/-- `O(1)`. Is the tree empty? -/
@[inline] def isEmpty : RBMap α β cmp → Bool := RBSet.isEmpty

/-- `O(n)`. Convert the tree to a list in ascending order. -/
@[inline] def toList : RBMap α β cmp → List (α × β) := RBSet.toList

/-- `O(log n)`. Returns the key-value pair `(a,b)` such that `a ≤ k` for all keys in the RBMap. -/
@[inline] protected def min : RBMap α β cmp → Option (α × β) := RBSet.min

/-- `O(log n)`. Returns the key-value pair `(a,b)` such that `a ≥ k` for all keys in the RBMap. -/
@[inline] protected def max : RBMap α β cmp → Option (α × β) := RBSet.max

instance [Repr α] [Repr β] : Repr (RBMap α β cmp) where
  reprPrec m prec := Repr.addAppParen ("RBMap.fromList " ++ repr m.toList) prec

/-- `O(log n)`. Insert key-value pair `(k,v)` into the tree. -/
@[inline] def insert (t : RBMap α β cmp) (k : α) (v : β) : RBMap α β cmp := RBSet.insert t (k, v)

/-- `O(log n)`. Remove an element `k` from the map. -/
@[inline] def erase (t : RBMap α β cmp) (k : α) : RBMap α β cmp := RBSet.erase t (cmp k ·.1)

/-- `O(n log n)`. Build a tree from an unsorted list by inserting them one at a time. -/
@[inline] def ofList (l : List (α × β)) (cmp : α → α → Ordering) : RBMap α β cmp :=
  RBSet.ofList l _

/-- `O(n log n)`. Build a tree from an unsorted array by inserting them one at a time. -/
@[inline] def ofArray (l : Array (α × β)) (cmp : α → α → Ordering) : RBMap α β cmp :=
  RBSet.ofArray l _

/-- `O(log n)`. Find an entry in the tree with key equal to `k`. -/
@[inline] def findEntry? (t : RBMap α β cmp) (k : α) : Option (α × β) := t.findP? (cmp k ·.1)

/-- `O(log n)`. Find the value corresponding to key `k`. -/
@[inline] def find? (t : RBMap α β cmp) (k : α) : Option β := t.findEntry? k |>.map (·.2)

/-- `O(log n)`. Find the value corresponding to key `k`, or return `v₀` if it is not in the map. -/
@[inline] def findD (t : RBMap α β cmp) (k : α) (v₀ : β) : β := (t.find? k).getD v₀

/--
`O(log n)`. `lowerBound? k` retrieves the key-value pair of the largest key
smaller than or equal to `k`, if it exists.
-/
@[inline] def lowerBound? (t : RBMap α β cmp) (k : α) : Option (α × β) :=
   RBSet.lowerBoundP? t (cmp k ·.1)

/-- `O(log n)`. Returns true if the given key `a` is in the RBMap. -/
@[inline] def contains (t : RBMap α β cmp) (a : α) : Bool := (t.findEntry? a).isSome

/-- `O(n)`. Returns true if the given predicate is true for all items in the RBMap. -/
@[inline] def all (t : RBMap α β cmp) (p : α → β → Bool) : Bool := RBSet.all t fun (a, b) => p a b

/-- `O(n)`. Returns true if the given predicate is true for any item in the RBMap. -/
@[inline] def any (t : RBMap α β cmp) (p : α → β → Bool) : Bool := RBSet.all t fun (a, b) => p a b

/-- `O(n)`. The number of items in the RBMap. -/
def size : RBMap α β cmp → Nat := RBSet.size

/-- `O(log n)`. Returns the minimum element of the map, or panics if the map is empty. -/
@[inline] def min! [Inhabited α] [Inhabited β] : RBMap α β cmp → α × β := RBSet.min!

/-- `O(log n)`. Returns the maximum element of the map, or panics if the map is empty. -/
@[inline] def max! [Inhabited α] [Inhabited β] : RBMap α β cmp → α × β := RBSet.max!

/-- Attempts to find the value with key `k : α` in `t` and panics if there is no such key. -/
@[inline] def find! [Inhabited β] (t : RBMap α β cmp) (k : α) : β :=
  (t.find? k).getD (panic! "key is not in the map")

/--
`O(n₂ * log (n₁ + n₂))`. Merges the maps `t₁` and `t₂`, if a key `a : α` exists in both,
then use `mergeFn a b₁ b₂` to produce the new merged value.
-/
def mergeBy (mergeFn : α → β → β → β) (t₁ t₂ : RBMap α β cmp) : RBMap α β cmp :=
  RBSet.mergeBy (fun (_, b₁) (a, b₂) => (a, mergeFn a b₁ b₂)) t₁ t₂

/--
`O(n₁ * log (n₁ + n₂))`. Intersects the maps `t₁` and `t₂`
using `mergeFn a b` to produce the new value.
-/
def intersectBy (mergeFn : α → β → γ → δ)
    (t₁ : RBMap α β cmp) (t₂ : RBMap α γ cmp) : RBMap α δ cmp :=
  RBSet.intersectBy (cmp ·.1 ·.1) (fun (a, b₁) (_, b₂) => (a, mergeFn a b₁ b₂)) t₁ t₂

/-- `O(n * log n)`. Constructs the set of all elements satisfying `p`. -/
def filter (t : RBMap α β cmp) (p : α → β → Bool) : RBMap α β cmp :=
  RBSet.filter t fun (a, b) => p a b

/--
`O(n₁ * (log n₁ + log n₂))`. Constructs the set of all elements of `t₁` that are not in `t₂`.
-/
def sdiff (t₁ t₂ : RBMap α β cmp) : RBMap α β cmp := t₁.filter fun a _ => !t₂.contains a

end RBMap
end Std
open Std

@[inheritDoc RBMap.ofList]
abbrev List.toRBMap (l : List (α × β)) (cmp : α → α → Ordering) : RBMap α β cmp :=
  RBMap.ofList l cmp
