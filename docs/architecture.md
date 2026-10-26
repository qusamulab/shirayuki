# Architecture

```
Tweak/Tweak.xm          Logos entry point and floating button
        │
GUI/Controllers/        panel lifecycle and routing; Layout / Actions categories
        ├── Components/ reusable UIKit views, cells, toast, search history
        ├── Support/    theme, input parsing, dispatch, C++ scan bridge
        └── Handlers/   one ObjC++ handler per tab and SYTabHandler protocol
                │
ShirayukiMemory/        pure C++ — Mach VM, scanning, patching, persistence
```

## The layering rule

**`ShirayukiMemory/` contains no Objective-C.** Not `NSString`, not
`NSJSONSerialization`, not Foundation.

This is not stylistic. It is what makes the [test suite](development.md) possible:
the Mach VM APIs the core uses (`vm_read_overwrite`, `vm_region_recurse_64`,
`_dyld_*`) all exist on macOS, so the whole core compiles and *runs* on a
development machine. Adding one Foundation call would end that.

The rule has been broken before — session persistence lived in a `Session.mm` that
used `NSJSONSerialization` to read files whose writer was hand-rolled C++. The two
halves were not round-trip compatible, and nothing noticed because the read path
had no caller. It is now `Session.cpp` on a small in-tree `Json` reader/writer.

## Feature headers

Each core API has a matching header: `Memory.hpp`, `Image.hpp`, `Scanner.hpp`,
`ValueFormat.hpp`, `Patch.hpp`, `Hex.hpp` and `Disasm.hpp`. Implementations include
only their dependencies. `ShirayukiMemory.hpp` still includes these APIs for
existing clients, so the public umbrella remains compatible. Additional APIs
such as `Freeze.hpp` and `Session.hpp` remain explicit includes.

## The C++/ObjC boundary

There is no technical barrier. ObjC++ (`.mm`) files use C++ freely, including
templates inside `dispatch_async` blocks.

!!! warning "Two constraints this project used to document, both false"
    Earlier notes claimed clang rejected C++ template syntax inside `.mm` dispatch
    blocks, and that `__weak typeof(self)` was rejected in *nested* dispatch blocks.
    Both were verified false against Apple clang.

    The weak-self failure was real but misdiagnosed: `typeof` is a GNU extension,
    and `-std=c++17` disables it. The fix was the build flag, not avoiding
    weak-self. Avoiding it caused a retain cycle that kept a 500 ms timer running
    for the life of the process.

`Shirayuki_CCFLAGS` must therefore be **`-std=gnu++17`**, not `-std=c++17`.

### C linkage still matters

`GUI/Support/SYInput.m` is compiled as plain Objective-C, so it exports C symbols. Its
declarations are wrapped in `extern "C"` for C++ callers. Without that, an ObjC++
caller mangles the call and the link fails — and `-fsyntax-only` cannot see it,
because both translation units type-check fine in isolation. That is why
`make syntax-check` also links.

## Where type behaviour lives

Everything type-dependent is in **`ShirayukiMemory/ValueFormat.cpp`**: byte width,
tag vocabulary, parsing, formatting, comparison. Adding a `ValueType` means
touching that file and the enum — not writing a new `switch`.

The same ten-arm switch was once spelled out in six places in the core plus three
more in the GUI, and they had drifted apart from each other.

### Two formatting functions, not one

| | Purpose | Round-trippable |
|---|---|---|
| `ValueFormat::format` | edit fields, session files, JSON export | **yes** — `parse(format(x)) == x` bit-exactly |
| `ValueFormat::formatDisplay` | table cell text | no — annotates integers as `42 (0x2A)` |

They are not interchangeable. A single function that annotated some types produced
output that could not be read back, and annotated inconsistently.

### Tag vocabulary

Two spellings per type, both accepted everywhere:

- **canonical** — `int32`, `float`, `uint64`. Stable; used in session files.
- **short** — `i32`, `f32`, `u64`. Compact; used on the type button.

`ValueFormat::toTag` returns canonical, `fromTag` accepts either. `tryFromTag`
reports an unknown tag instead of silently coercing it to `Int32`.

## Invariants worth knowing

These each correspond to a bug that shipped.

**Never compare typed values with `memcmp`.** Use `compareTypedBytes`. Bytewise
comparison is wrong on little-endian ARM64 for every multi-byte type and for all
signed and floating point values — `1 → 256` is an increase, but its low byte
decreases. This was introduced twice: in search narrowing and in conditional
freeze.

**Never dereference target memory directly.** Region lists come from a
`vm_region` snapshot while the host app keeps running, so a range that was mapped
when it was listed can be freed moments later. A direct load faults the whole host
process; a failed `Memory::read` only skips a chunk. `Scanner` reads chunked
copies, with overlap so a match straddling a chunk boundary is found exactly once.

**Check read and write status.** A failed read leaving a zeroed buffer is
indistinguishable from a real `0`. `Memory::readValue` returns `Status`;
`tryReadValue` returns `std::optional`. Displaying an unchecked `0` in an editable
field is how a failed read became a real zero write.

**Check `ValueFormat::parse`'s return.** `0` means rejected. Writing the zeroed
buffer anyway turns a typo into a wrong memory write.

**Bound anything sized from user input before allocating.** `Hex::dump` used to
allocate and zero-fill a caller-supplied length before reading, so a mistyped
length exhausted memory.

**Distinguish heap from stack by allocator tag, not address.** On arm64 the entire
user address space sits above 4 GB, so an address threshold classifies nothing.
`RegionInfo::userTag` carries the kernel `VM_MEMORY_*` tag; `DataOnly` uses real
Mach-O `__DATA*` segment bounds.

## Background workers

`FreezeManager` (16 ms) and `WatchManager` (100 ms) each own a thread.

- Both are mutex-guarded, and **callbacks fire outside the lock** — deliberately,
  to avoid re-entering the manager from a callback.
- Both wait on a `condition_variable` rather than sleeping, so `stop()` returns
  promptly instead of blocking for a whole interval.
- `start()`/`stop()` are serialised: assigning to a still-joinable `std::thread`
  calls `std::terminate`.
- The singletons are **deliberately leaked**. A function-local static would be
  destroyed at `atexit`, and joining a worker thread during host-process teardown
  is a known way to deadlock. Their constructors are public so tests can own an
  instance instead.

## Tabs

Each tab is one class implementing `SYTabHandler` (`GUI/Handlers/SYTabHandler.h`): title,
icon, placeholder, type label, action icon, plus `performAction:` and the table
data methods. Optional hooks cover row selection, deletion, long-press and row
height.

`ShirayukiViewController` owns the handler array and routes to the selected one.

View construction lives in `ShirayukiViewController+Layout.mm`; action sheets and
memory editing live in `+Actions.mm`. `+Private.h` shares internal properties
without expanding the public controller API. Concrete handler references keep
cross-tab actions independent of tab ordering.

Search results use `Scanner::Candidate` directly, including their byte snapshots.
The handler delegates narrowing to `Scanner::narrowResults`; the GUI does not
maintain a second comparison implementation. Numeric scan widths come from
`ValueFormat`; the bridge sends them directly to `findValueBytes`.

`SYSearchHistoryView` owns a separate table and backdrop. History rows cannot be
routed to result editing or deletion, and its height is recalculated on each show.
Handlers can expose `isBusy`, `statusText` and `emptyStateMessage` for panel
feedback. Busy scans disable submission, type changes and result interaction.

## Configuration

All limits and tunables are in **`ShirayukiMemory/ShirayukiConfig.hpp`** —
scan caps, chunk size, worker intervals, the widest value size, dump bounds. New
magic numbers belong there. It was previously included by 2 of 12 translation
units, with the same constants duplicated as literals elsewhere.

## Injection filter

`Shirayuki.plist` decides which processes the tweak loads into. It filters on
`com.apple.UIKit`, which matches every UIKit application — including system apps.

```
{ Filter = { Bundles = ( "com.your.game" ); }; }
```

!!! warning
    It is an *old-style* plist, not XML, and it must stay comment-free. A parse
    failure is silent: the tweak simply never loads. It shipped once with the
    literal placeholder `com.example.targetapp`, so it matched nothing at all.
