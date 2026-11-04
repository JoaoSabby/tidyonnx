#include <immintrin.h>
#include <cstdio>

// Volatile input requires the CPU to execute the profile's AVX-512 VNNI instructions.
int main(int argc, char**) {
  alignas(64) volatile unsigned char input[64];
  alignas(64) unsigned char bytes[64];
  alignas(64) int output[16];
  for (int index = 0; index < 64; ++index) {
    input[index] = static_cast<unsigned char>(argc);
    bytes[index] = input[index];
  }
  const auto values = _mm512_load_si512(bytes);
  const auto result = _mm512_dpbusd_epi32(_mm512_setzero_si512(), values, values);
  _mm512_store_si512(output, result);
  for (int index = 0; index < 16; ++index) {
    if (output[index] != 4 * argc * argc) return 1;
  }
  std::puts("Cascade Lake AVX-512 VNNI execution probe passed.");
  return 0;
}
