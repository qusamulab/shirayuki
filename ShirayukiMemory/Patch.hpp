#ifndef SHIRAYUKI_PATCH_HPP
#define SHIRAYUKI_PATCH_HPP

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace Shirayuki {

// --- Memory patch (apply/restore) ---
class Patch {
  public:
    static Patch createWithBytes(uintptr_t address, const void *bytes, size_t len);
    static Patch createWithHex(uintptr_t address, const std::string &hex);
    static Patch createNop(uintptr_t address, size_t count);

    bool isValid() const {
        return m_address != 0 && !m_patchBytes.empty();
    }
    uintptr_t address() const {
        return m_address;
    }
    size_t size() const {
        return m_patchBytes.size();
    }
    std::string label() const {
        return m_label;
    }
    void setLabel(const std::string &l) {
        m_label = l;
    }

    bool apply();
    bool restore();
    bool isApplied() const;

    std::vector<uint8_t> originalBytes() const {
        return m_origBytes;
    }
    std::vector<uint8_t> patchBytes() const {
        return m_patchBytes;
    }
    std::string currentHex() const;
    std::string originalHex() const;
    std::string patchHex() const;

  private:
    uintptr_t m_address = 0;
    std::vector<uint8_t> m_origBytes;
    std::vector<uint8_t> m_patchBytes;
    std::string m_label;
    bool m_applied = false;
};

} // namespace Shirayuki

#endif // SHIRAYUKI_PATCH_HPP
