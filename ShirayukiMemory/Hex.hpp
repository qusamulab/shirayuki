#ifndef SHIRAYUKI_HEX_HPP
#define SHIRAYUKI_HEX_HPP

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace Shirayuki {

// --- Hex utilities ---
namespace Hex {
std::vector<uint8_t> toBytes(const std::string &hex);
std::string fromBytes(const void *data, size_t len);
std::string fromBytes(const std::vector<uint8_t> &data);
std::string dump(uintptr_t address, size_t len, size_t bytesPerLine = 16);
bool isValid(const std::string &hex);
} // namespace Hex

} // namespace Shirayuki

#endif // SHIRAYUKI_HEX_HPP
