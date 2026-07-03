/*
 * Measures real elapsed wall-clock time of a sleep(10) call.
 * Used to verify that mid-sleep rate changes take effect.
 *
 * Build: cc -o sleep_elapsed sleep_elapsed.c
 * Run with: FAKETIME_TIMESTAMP_FILE=/tmp/ft_sleep_test FAKETIME_DONT_FAKE_MONOTONIC=1 \
 *           DYLD_INSERT_LIBRARIES=../src/libfaketime.1.dylib DYLD_FORCE_FLAT_NAMESPACE=1 \
 *           ./sleep_elapsed
 */
#include <stdio.h>
#include <time.h>
#include <unistd.h>

int main()
{
  struct timespec start, end;

  /* Use CLOCK_MONOTONIC for real wall-clock measurement.
   * FAKETIME_DONT_FAKE_MONOTONIC=1 must be set in the environment. */
  clock_gettime(CLOCK_MONOTONIC, &start);

  printf("MARKER_START\n");
  fflush(stdout);
  sleep(10);
  printf("MARKER_END\n");
  fflush(stdout);

  clock_gettime(CLOCK_MONOTONIC, &end);

  double elapsed = (end.tv_sec - start.tv_sec) +
                   (end.tv_nsec - start.tv_nsec) / 1000000000.0;
  printf("ELAPSED=%.3f\n", elapsed);
  return 0;
}
