#ifndef SHIRAYUKI_IMAGE_HPP
#define SHIRAYUKI_IMAGE_HPP

#include <cstdint>
#include <string>
#include <vector>

namespace Shirayuki {

// --- Image info (loaded binary) ---
struct ImageInfo {
    std::string name;
    uintptr_t base = 0;
    intptr_t slide = 0;

    bool isValid() const {
        return base != 0;
    }
};
// --- Image / module utilities ---
namespace Image {
ImageInfo find(const std::string &imageName);
ImageInfo getBase();
std::vector<ImageInfo> listAll();
uintptr_t absoluteAddress(const ImageInfo &img, uintptr_t offset);
uintptr_t absoluteAddress(const std::string &imageName, uintptr_t offset);

// Symbol resolution
uintptr_t findSymbol(const std::string &imageName, const std::string &symbolName);
uintptr_t findSymbol(const ImageInfo &img, const std::string &symbolName);
} // namespace Image

} // namespace Shirayuki

#endif // SHIRAYUKI_IMAGE_HPP
