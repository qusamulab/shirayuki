#ifndef SHIRAYUKI_DISASM_HPP
#define SHIRAYUKI_DISASM_HPP

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace Shirayuki {

// --- Disassembly (ARM64) ---
namespace Disasm {
struct Instruction {
    uintptr_t address;
    uint32_t opcode;
    std::string mnemonic; // simplified
    std::string operands;
};

// Disassemble ARM64 instructions at address
std::vector<Instruction> disassemble(uintptr_t address, size_t count);
std::string formatInstruction(const Instruction &insn);
} // namespace Disasm

} // namespace Shirayuki

#endif // SHIRAYUKI_DISASM_HPP
