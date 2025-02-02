/-
Copyright (c) 2019 Microsoft Corporation. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Leonardo de Moura, Mario Carneiro
-/
import Std.Data.List.Basic

namespace Std

/--
`AssocList α β` is "the same as" `List (α × β)`, but flattening the structure
leads to one fewer pointer indirection (in the current code generator).
It is mainly intended as a component of `HashMap`, but it can also be used as a plain
key-value map.
-/
inductive AssocList (α : Type u) (β : Type v) where
  /-- An empty list -/
  | nil
  /-- Add a `key, value` pair to the list -/
  | cons (key : α) (value : β) (tail : AssocList α β)
  deriving Inhabited

namespace AssocList

/--
`O(n)`. Convert an `AssocList α β` into the equivalent `List (α × β)`.
This is used to give specifications for all the `AssocList` functions
in terms of corresponding list functions.
-/
@[simp] def toList : AssocList α β → List (α × β)
  | nil => []
  | cons a b es => (a, b) :: es.toList

instance : EmptyCollection (AssocList α β) := ⟨nil⟩

@[simp] theorem empty_eq : (∅ : AssocList α β) = nil := rfl

/-- `O(1)`. Is the list empty? -/
def isEmpty : AssocList α β → Bool
  | nil => true
  | _   => false

@[simp] theorem isEmpty_eq (l : AssocList α β) : isEmpty l = l.toList.isEmpty := by
  cases l <;> simp [*, isEmpty, List.isEmpty]

/-- `O(n)`. Fold a monadic function over the list, from head to tail. -/
@[specialize] def foldlM [Monad m] (f : δ → α → β → m δ) : (init : δ) → AssocList α β → m δ
  | d, nil         => pure d
  | d, cons a b es => do foldlM f (← f d a b) es

@[simp] theorem foldlM_eq [Monad m] (f : δ → α → β → m δ) (init l) :
    foldlM f init l = l.toList.foldlM (fun d (a, b) => f d a b) init := by
  induction l generalizing init <;> simp [*, foldlM]

/-- `O(n)`. Fold a function over the list, from head to tail. -/
@[inline] def foldl (f : δ → α → β → δ) (init : δ) (as : AssocList α β) : δ :=
  Id.run (foldlM f init as)

@[simp] theorem foldl_eq (f : δ → α → β → δ) (init l) :
    foldl f init l = l.toList.foldl (fun d (a, b) => f d a b) init := by
  simp [List.foldl_eq_foldlM, foldl, Id.run]

/-- Optimized version of `toList`. -/
def toListTR (as : AssocList α β) : List (α × β) :=
  as.foldl (init := #[]) (fun r a b => r.push (a, b)) |>.toList

@[csimp] theorem toList_eq_toListTR : @toList = @toListTR := by
  funext α β as; simp [toListTR]
  exact .symm <| (Array.foldl_data_eq_map (toList as) _ id).trans (List.map_id _)

/-- `O(n)`. Run monadic function `f` on all elements in the list, from head to tail. -/
@[specialize] def forM [Monad m] (f : α → β → m PUnit) : AssocList α β → m PUnit
  | nil         => pure ⟨⟩
  | cons a b es => do f a b; forM f es

@[simp] theorem forM_eq [Monad m] (f : α → β → m PUnit) (l) :
    forM f l = l.toList.forM (fun (a, b) => f a b) := by
  induction l <;> simp [*, forM]

/-- `O(n)`. Map a function `f` over the keys of the list. -/
@[simp] def mapKey (f : α → δ) : AssocList α β → AssocList δ β
  | nil        => nil
  | cons k v t => cons (f k) v (mapKey f t)

@[simp] theorem mapKey_toList (f : α → δ) (l : AssocList α β) :
    (mapKey f l).toList = l.toList.map (fun (a, b) => (f a, b)) := by
  induction l <;> simp [*]

/-- `O(n)`. Map a function `f` over the values of the list. -/
@[simp] def mapVal (f : α → β → δ) : AssocList α β → AssocList α δ
  | nil        => nil
  | cons k v t => cons k (f k v) (mapVal f t)

@[simp] theorem mapVal_toList (f : α → β → δ) (l : AssocList α β) :
    (mapVal f l).toList = l.toList.map (fun (a, b) => (a, f a b)) := by
  induction l <;> simp [*]

/-- `O(n)`. Returns the first entry in the list whose entry satisfies `p`. -/
@[specialize] def findEntryP? (p : α → β → Bool) : AssocList α β → Option (α × β)
  | nil         => none
  | cons k v es => bif p k v then some (k, v) else findEntryP? p es

@[simp] theorem findEntryP?_eq (p : α → β → Bool) (l : AssocList α β) :
    findEntryP? p l = l.toList.find? fun (a, b) => p a b := by
  induction l <;> simp [findEntryP?]; split <;> simp [*]

/-- `O(n)`. Returns the first entry in the list whose key is equal to `a`. -/
@[inline] def findEntry? [BEq α] (a : α) (l : AssocList α β) : Option (α × β) :=
  findEntryP? (fun k _ => k == a) l

@[simp] theorem findEntry?_eq [BEq α] (a : α) (l : AssocList α β) :
    findEntry? a l = l.toList.find? (·.1 == a) := findEntryP?_eq ..

/-- `O(n)`. Returns the first value in the list whose key is equal to `a`. -/
def find? [BEq α] (a : α) : AssocList α β → Option β
  | nil         => none
  | cons k v es => match k == a with
    | true  => some v
    | false => find? a es

theorem find?_eq_findEntry? [BEq α] (a : α) (l : AssocList α β) :
    find? a l = (l.findEntry? a).map (·.2) := by
  induction l <;> simp [find?]; split <;> simp [*]

@[simp] theorem find?_eq [BEq α] (a : α) (l : AssocList α β) :
    find? a l = (l.toList.find? (·.1 == a)).map (·.2) := by simp [find?_eq_findEntry?]

/-- `O(n)`. Returns true if any entry in the list satisfies `p`. -/
@[specialize] def any (p : α → β → Bool) : AssocList α β → Bool
  | nil         => false
  | cons k v es => p k v || any p es

@[simp] theorem any_eq (p : α → β → Bool) (l : AssocList α β) :
    any p l = l.toList.any fun (a, b) => p a b := by induction l <;> simp [any, *]

/-- `O(n)`. Returns true if every entry in the list satisfies `p`. -/
@[specialize] def all (p : α → β → Bool) : AssocList α β → Bool
  | nil         => true
  | cons k v es => p k v && all p es

@[simp] theorem all_eq (p : α → β → Bool) (l : AssocList α β) :
    all p l = l.toList.all fun (a, b) => p a b := by induction l <;> simp [all, *]

/-- Returns true if every entry in the list satisfies `p`. -/
def All (p : α → β → Prop) (l : AssocList α β) : Prop := ∀ a ∈ l.toList, p a.1 a.2

/-- `O(n)`. Returns true if there is an element in the list whose key is equal to `a`. -/
@[inline] def contains [BEq α] (a : α) (l : AssocList α β) : Bool := any (fun k _ => k == a) l

@[simp] theorem contains_eq [BEq α] (a : α) (l : AssocList α β) :
    contains a l = l.toList.any (·.1 == a) := by
  induction l <;> simp [*, contains]

/--
`O(n)`. Replace the first entry in the list
with key equal to `a` to have key `a` and value `b`.
-/
@[simp] def replace [BEq α] (a : α) (b : β) : AssocList α β → AssocList α β
  | nil         => nil
  | cons k v es => match k == a with
    | true  => cons a b es
    | false => cons k v (replace a b es)

@[simp] theorem replace_toList [BEq α] (a : α) (b : β) (l : AssocList α β) :
    (replace a b l).toList =
    l.toList.replaceF (bif ·.1 == a then (a, b) else none) := by
  induction l <;> simp [replace]; split <;> simp [*]

/-- `O(n)`. Remove the first entry in the list with key equal to `a`. -/
@[specialize, simp] def eraseP (p : α → β → Bool) : AssocList α β → AssocList α β
  | nil         => nil
  | cons k v es => bif p k v then es else cons k v (eraseP p es)

@[simp] theorem eraseP_toList (p) (l : AssocList α β) :
    (eraseP p l).toList = l.toList.eraseP fun (a, b) => p a b := by
  induction l <;> simp [List.eraseP, cond]; split <;> simp [*]

/-- `O(n)`. Remove the first entry in the list with key equal to `a`. -/
@[inline] def erase [BEq α] (a : α) (l : AssocList α β) : AssocList α β :=
  eraseP (fun k _ => k == a) l

@[simp] theorem erase_toList [BEq α] (a : α) (l : AssocList α β) :
    (erase a l).toList = l.toList.eraseP (·.1 == a) := eraseP_toList ..

/-- The implementation of `ForIn`, which enables `for (k, v) in aList do ...` notation. -/
@[specialize] protected def forIn [Monad m]
    (as : AssocList α β) (init : δ) (f : (α × β) → δ → m (ForInStep δ)) : m δ :=
  match as with
  | nil => pure init
  | cons k v es => do
    match (← f (k, v) init) with
    | ForInStep.done d  => pure d
    | ForInStep.yield d => es.forIn d f

instance : ForIn m (AssocList α β) (α × β) where
  forIn := AssocList.forIn

@[simp] theorem forIn_eq [Monad m] (l : AssocList α β) (init : δ)
    (f : (α × β) → δ → m (ForInStep δ)) : forIn l init f = forIn l.toList init f := by
  simp [forIn, List.forIn]
  induction l generalizing init <;> simp [AssocList.forIn, List.forIn.loop]
  congr; funext a; split <;> simp [*]

/-- Converts a list into an `AssocList`. This is the inverse function to `AssocList.toList`. -/
@[simp] def _root_.List.toAssocList : List (α × β) → AssocList α β
  | []          => nil
  | (a,b) :: es => cons a b (toAssocList es)

@[simp] theorem _root_.List.toAssocList_toList (l : List (α × β)) : l.toAssocList.toList = l := by
  induction l <;> simp [*]

@[simp] theorem toList_toAssocList (l : AssocList α β) : l.toList.toAssocList = l := by
  induction l <;> simp [*]
