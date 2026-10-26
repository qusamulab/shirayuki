#ifndef SHIRAYUKI_MEMORY_OPERATIONS_HPP
#define SHIRAYUKI_MEMORY_OPERATIONS_HPP

#include <cstddef>
#include <cstdint>
#include <mach/mach.h>
#include <optional>
#include <string>
#include <vector>

namespace Shirayuki {

// --- Status codes ---
enum class Status {
    Success = 0,
    Failed,
    InvalidAddress,
    InvalidLength,
    InvalidBuffer,
    ProtectionFailed,
    TaskFailed
};
// --- Memory region info ---
struct RegionInfo {
    std::string label; // human-readable kind: "MALLOC", "STACK", "__TEXT", ...
    uintptr_t start = 0;
    size_t size = 0;
    vm_prot_t protection = VM_PROT_NONE;
    // Kernel VM_MEMORY_* allocator tag. This, not the address range, is what
    // reliably distinguishes heap from stack: on arm64 the entire user address
    // space sits above 4 GB, so an address threshold classifies nothing.
    unsigned int userTag = 0;

    bool isReadable() const {
        return protection & VM_PROT_READ;
    }
    bool isWritable() const {
        return protection & VM_PROT_WRITE;
    }
    bool isExecutable() const {
        return protection & VM_PROT_EXECUTE;
    }
    bool isHeap() const;
    bool isStack() const;
};

// --- Region filter for scans ---
enum class RegionFilter {
    All = 0,
    HeapOnly,   // rw-, anonymous
    DataOnly,   // __DATA segments
    StackOnly,  // stack regions
    ReadWrite,  // any rw-
    Executable, // r-x
};

// --- Core memory operations ---
namespace Memory {
Status read(uintptr_t address, void *buffer, size_t len);
Status write(uintptr_t address, const void *buffer, size_t len);

// Read a typed value, reporting failure. An unreadable address is otherwise
// indistinguishable from one that legitimately holds 0 — and a caller that
// displays that 0 in an editable field will happily write it back, turning a
// failed read into real memory corruption.
template <typename T> Status readValue(uintptr_t address, T &out) {
    return read(address, &out, sizeof(T));
}

// Convenience form for callers that have already validated the address, or for
// which a zero on failure is genuinely harmless. Prefer the two-argument form.
template <typename T> std::optional<T> tryReadValue(uintptr_t address) {
    T val{};
    if (read(address, &val, sizeof(T)) != Status::Success)
        return std::nullopt;
    return val;
}

template <typename T> Status writeValue(uintptr_t address, T value) {
    return write(address, &value, sizeof(T));
}

RegionInfo getRegionInfo(uintptr_t address);
Status protect(uintptr_t address, size_t len, vm_prot_t prot);
std::vector<RegionInfo> listRegions(vm_prot_t requiredProt = VM_PROT_NONE);
std::vector<RegionInfo> listRegionsFiltered(RegionFilter filter);
} // namespace Memory

} // namespace Shirayuki

#endif // SHIRAYUKI_MEMORY_OPERATIONS_HPP
