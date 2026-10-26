#include "SYScanHelper.hpp"
#include "ValueFormat.hpp"
#include "syharness.hpp"

#include <algorithm>
#include <array>
#include <cstring>

using namespace Shirayuki;

static void testNumericTypes() {
    struct Sample {
        const char *tag;
        const char *input;
    };
    const Sample samples[] = {
        {"int8", "-12"},
        {"uint8", "251"},
        {"int16", "-1234"},
        {"uint16", "65000"},
        {"int32", "-123456"},
        {"uint32", "4000000000"},
        {"int64", "-1234567890123"},
        {"uint64", "18446744073709551615"},
        {"float", "-0.0"},
        {"double", "123.25"},
    };
    for (const auto &sample : samples) {
        alignas(8) std::array<uint8_t, 128> memory;
        memory.fill(0xAA);
        uint8_t bytes[kMaxValueSize] = {};
        size_t width = ValueFormat::parse(sample.input, ValueFormat::fromTag(sample.tag), bytes);
        SY_CHECK(width > 0);
        std::memcpy(memory.data(), bytes, width);
        std::memcpy(memory.data() + 64, bytes, width);
        ScanResults hits;
        hits.data = SYScanRegion(reinterpret_cast<uintptr_t>(memory.data()), memory.size(),
                                 sample.tag, sample.input, &hits.count, &hits.valSize);
        SY_CHECK_EQ(hits.valSize, width);
        SY_CHECK_EQ(hits.count, 2u);
        if (hits.count == 2) {
            SY_CHECK_EQ(hits.data[0], reinterpret_cast<uintptr_t>(memory.data()));
            SY_CHECK_EQ(hits.data[1], reinterpret_cast<uintptr_t>(memory.data() + 64));
        }
    }
}

static void testRawSearches() {
    const char text[] = "a long string exceeding the eight byte value buffer";
    for (const char *type : {"string", "regex"}) {
        ScanResults hits;
        hits.data = SYScanRegion(reinterpret_cast<uintptr_t>(text), sizeof(text), type, text,
                                 &hits.count, &hits.valSize);
        SY_CHECK_EQ(hits.count, 1u);
        // Raw queries must never request a numeric snapshot of the string's length.
        SY_CHECK_EQ(hits.valSize, 0u);
    }
    const uint8_t bytes[] = {0xFF, 0x00, 0x42, 0x01};
    ScanResults hits;
    hits.data = SYScanRegion(reinterpret_cast<uintptr_t>(bytes), sizeof(bytes), "hex",
                             "FF 00 ?? 01", &hits.count, &hits.valSize);
    SY_CHECK_EQ(hits.count, 1u);
    SY_CHECK_EQ(hits.valSize, 0u);
}

static void testRejectedInputAndBoundedReads() {
    int32_t value = 42;
    ScanResults hits;
    hits.data = SYScanRegion(reinterpret_cast<uintptr_t>(&value), sizeof(value), "int32",
                             "not a number", &hits.count, &hits.valSize);
    SY_CHECK_EQ(hits.count, 0u);
    SY_CHECK(hits.data == nullptr);

    std::array<uint8_t, 32> source;
    source.fill(0xAB);
    std::array<uint8_t, 32> destination{};
    uintptr_t address = reinterpret_cast<uintptr_t>(source.data());
    SY_CHECK_EQ(SYMemRead(address, destination.data(), 16), 0);
    SY_CHECK(std::all_of(destination.begin(), destination.end(), [](uint8_t b) { return b == 0; }));
    SY_CHECK_EQ(SYMemRead(address, destination.data(), 0), 0);
    SY_CHECK_EQ(SYMemRead(0, destination.data(), kMaxValueSize), 0);
    SY_CHECK_EQ(SYMemRead(address, destination.data(), kMaxValueSize), 1);
    SY_CHECK_EQ(destination[0], 0xAB);
    SY_CHECK_EQ(destination[kMaxValueSize], 0);
}

static void run() {
    testNumericTypes();
    testRawSearches();
    testRejectedInputAndBoundedReads();
}

SY_MAIN("test_scanhelper")
