#ifndef SHIRAYUKI_VALUEFORMAT_HPP
#define SHIRAYUKI_VALUEFORMAT_HPP

#include "ShirayukiConfig.hpp"
#include <string>
#include <vector>

namespace Shirayuki {

// --- Search value type ---
enum class ValueType { Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64 };

size_t valueTypeSize(ValueType type);
std::string valueTypeLabel(ValueType type);

// Typed 3-way comparison of two same-typed values (a and b must be at least
// valueTypeSize(type) bytes). Returns -1/0/+1 like memcmp — but interprets
// the bytes according to the given ValueType (so signed/float compare correctly).
int compareTypedBytes(const uint8_t *a, const uint8_t *b, ValueType type);

// --- Scanner compare mode (for narrowing) ---
enum class CompareMode {
    Exact,
    Changed,
    Unchanged,
    Increased,
    Decreased,
    GreaterThan,
    LessThan,
};
// --- Value formatting and parsing ---
namespace ValueFormat {
// Format raw bytes as a plain value string, with no decoration. Guaranteed
// round-trippable: parse(format(buf, t), t, buf2) reproduces buf exactly.
// Use this for edit fields, session files and JSON export.
std::string format(const uint8_t *buf, ValueType type);

// Format raw bytes for display in a table cell: integers gain a hex annotation
// ("42 (0x2A)"), floats use fixed notation. Not parseable — display only.
std::string formatDisplay(const uint8_t *buf, ValueType type);

// Parse a decimal or 0x-prefixed hexadecimal string into raw bytes for the
// given type. Returns the number of bytes written, or 0 if the input is empty,
// malformed, has trailing characters, or is out of range for the type; `buf` is
// zeroed either way. Never throws — callers pass raw text field contents.
size_t parse(const std::string &input, ValueType type, uint8_t buf[kMaxValueSize]);

// Resolve a type tag. Both the canonical tag ("int32", "float") and the compact
// label ("i32", "f32") are accepted, as are the "float32"/"float64" aliases.
// fromTag falls back to Int32 for unknown tags; use tryFromTag when an
// unrecognised tag should be reported to the user instead of silently coerced.
bool tryFromTag(const std::string &tag, ValueType &out);
ValueType fromTag(const std::string &tag);

// Canonical, stable string tag for a type ("int32"). Round-trips through
// fromTag. For the compact UI label use valueTypeLabel.
std::string toTag(ValueType type);

// Canonical tags of every ValueType, in enumerator order.
std::vector<std::string> allTags();
} // namespace ValueFormat

} // namespace Shirayuki

#endif // SHIRAYUKI_VALUEFORMAT_HPP
