# hdl/mem.bend: a memory of w-bit words, addressed by an n-bit Word.
#
# A binary trie walked from the address's lowest bit: MemZ{} is a subtree
# whose every word reads 0, so an empty 64K memory is one node. Register
# files are the same type with a 3-bit address.

import Base

type Mem<-w: Nat> is Data:
  MemZ{}
  MemL{v: Word(w)}
  MemN{lo: Mem<w>, hi: Mem<w>}

# the word at address a; 0 where nothing was written
def get(+w: Nat, n: Nat, a: Word(n), m: Mem<w>) -> Word(w):
  match n:
    case 0n:
      match m:
        case MemL{v}:
          v
        case _:
          Word.zero(w)
    case 1n+p:
      match a:
        case WCon{b, t}:
          match b m:
            case False{} MemN{lo, hi}:
              get(w, p, t, lo)
            case True{} MemN{lo, hi}:
              get(w, p, t, hi)
            case _ _:
              Word.zero(w)

# the memory with v at address a
def set(-w: Nat, n: Nat, a: Word(n), v: Word(w), m: Mem<w>) -> Mem<w>:
  match n:
    case 0n:
      MemL{v}
    case 1n+p:
      match a:
        case WCon{b, t}:
          match b m:
            case False{} MemN{lo, hi}:
              MemN{set(w, p, t, v, lo), hi}
            case True{} MemN{lo, hi}:
              MemN{lo, set(w, p, t, v, hi)}
            case False{} _:
              MemN{set(w, p, t, v, MemZ{}), MemZ{}}
            case True{} _:
              MemN{MemZ{}, set(w, p, t, v, MemZ{})}

# set when we is True, else m unchanged (a write port with an enable)
def write(-w: Nat, we: Bool, n: Nat, a: Word(n), v: Word(w), m: Mem<w>) -> Mem<w>:
  match we:
    case True{}:
      set(w, n, a, v, m)
    case False{}:
      m
