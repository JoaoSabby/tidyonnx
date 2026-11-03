/* Execute explicit AVX-512 arithmetic after the runner's CPU/OS feature check. */
#include <immintrin.h>
#include <stdio.h>
#include <time.h>
int main(void) {
  volatile float input[16];
  float output[16];
  float seed = (float)(clock() % 100);
  for (int index = 0; index < 16; ++index) input[index] = seed + index;
  __m512 values = _mm512_loadu_ps((const float*)input);
  values = _mm512_add_ps(values, _mm512_set1_ps(1.0f));
  _mm512_storeu_ps(output, values);
  for (int index = 0; index < 16; ++index) {
    if (output[index] != input[index] + 1.0f) return 1;
  }
  printf("AVX-512 execution probe: PASS (%g)\n", output[13]);
  return 0;
}
