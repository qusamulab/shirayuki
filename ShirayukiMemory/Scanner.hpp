#ifndef SHIRAYUKI_SCANNER_HPP
#define SHIRAYUKI_SCANNER_HPP

#include "Image.hpp"
#include "ValueFormat.hpp"
#include <cstring>

namespace Shirayuki {

// --- Memory scanner ---
namespace Scanner {
// IDA-style pattern (e.g. "FF 00 ?? 01 AB")
std::vector<uintptr_t> findPattern(uintptr_t start, size_t len, const std::string &pattern);
uintptr_t findPatternFirst(uintptr_t start, size_t len, const std::string &pattern);
std::vector<uintptr_t> findPatternInImage(const ImageInfo &img, const std::string &pattern);

// Find every occurrence of `width` needle bytes in [start, start+len).
//
// `stride` is the step between candidate offsets; it defaults to `width`, i.e.
// only naturally-aligned values are reported, which is what a typed scan wants.
// Pass 1 for a byte-granular search.
//
// Reads a copy of the range through Memory::read rather than dereferencing it.
// Region lists come from a vm_region snapshot, so by the time a scan runs the
// host app may already have freed or unmapped the range — a direct load would
// fault the whole process, where a failed read merely skips that chunk.
std::vector<uintptr_t> findValueBytes(uintptr_t start, size_t len, const uint8_t *needle,
                                      size_t width, size_t stride = 0);

// Typed value search — thin convenience wrapper over findValueBytes.
template <typename T> std::vector<uintptr_t> findValue(uintptr_t start, size_t len, T value) {
    uint8_t needle[sizeof(T)];
    memcpy(needle, &value, sizeof(T));
    return findValueBytes(start, len, needle, sizeof(T));
}

// String search
std::vector<uintptr_t> findString(uintptr_t start, size_t len, const std::string &str);

// Regex search (matches against null-terminated strings in the region)
std::vector<uintptr_t> findRegex(uintptr_t start, size_t len, const std::string &pattern);

// Fuzzy numeric search — matches values within ±tolerance of the given value.
// Only meaningful for Int32/Int64/Float32/Float64; other types return an empty result.
std::vector<uintptr_t> findValueFuzzy(uintptr_t start, size_t len, double value, double tolerance,
                                      ValueType type);

// Narrowing: filter candidates by comparing current vs snapshot
struct Candidate {
    uintptr_t address;
    std::vector<uint8_t> snapshotValue; // value at time of initial scan
};

std::vector<Candidate> narrowResults(const std::vector<Candidate> &candidates, ValueType type,
                                     CompareMode mode, const void *compareValue = nullptr);

// Seed candidates for an "unknown initial value" scan: enumerate every aligned slot of
// the given type in `[start, start+len)`, capturing the current bytes as the snapshot.
// The caller then narrows with CompareMode::Changed/Unchanged/Increased/Decreased.
// Bounded by `maxCandidates` to keep memory in check on large regions.
std::vector<Candidate> seedUnknownCandidates(uintptr_t start, size_t len, ValueType type,
                                             size_t maxCandidates);
} // namespace Scanner

} // namespace Shirayuki

#endif // SHIRAYUKI_SCANNER_HPP
