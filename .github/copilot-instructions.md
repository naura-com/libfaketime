# libfaketime Copilot Instructions

## Build & Test

```bash
# Build the library (auto-detects OS)
make

# Run full test suite (builds library + runs tests)
make test

# Run only functional tests (after building)
cd test && ./testframe.sh functests

# macOS: build and test
make -f Makefile.OSX -C src all
cd test && make -f Makefile.OSX && ./test_OSX.sh

# Custom build flags
FAKETIME_COMPILE_CFLAGS="-DFORCE_MONOTONIC_FIX -DINTERCEPT_SYSCALL" make

# Build for non-default prefix (useful for local testing)
make PREFIX=/tmp/libfaketime LIBDIRNAME='.'
```

There is no lint command. Warnings are treated as errors (`-Werror`) at build time.

## Architecture

```
┌─ faketime (wrapper binary) ─┐
│  Sets env vars, runs child  │──faketime_common.h──┐
└─────────────────────────────┘                      │
                                                     ▼
┌─ libfaketime.c (~4800 lines, single file) ──────────────┐
│  Intercepts ~40+ time-related syscalls                  │
│  ├─ Linux:   LD_PRELOAD + dlsym(RTLD_NEXT)              │
│  └─ macOS:   DYLD_INTERPOSE (__DATA,__interpose section)│
│                                                         │
│  Core flow per intercepted call:                        │
│  [call real] → [fake_gettimeofday/fake_clock_gettime]   │
│  → parse_ft_string() → apply offset/scale → return      │
│                                                         │
│  Subsystems:                                            │
│  ├─ ft_sem.c/h:  Semaphore abstraction (flock/POSIX/SYSV)│
│  ├─ faketime_common.h: Shared structs (cross-process SHM)│
│  ├─ time_ops.h:   timespec/timeval math macros          │
│  ├─ uthash.h:     Hash table (timer tracking)           │
│  └─ libfaketime.map: glibc versioned symbol exports     │
└─────────────────────────────────────────────────────────┘
```

**Two library variants** are built on Linux:
- `libfaketime.so.1` — standard
- `libfaketimeMT.so.1` — compiled with `-DPTHREAD_SINGLETHREADED_TIME` for single-threaded time access

On **macOS**, a single fat binary `libfaketime.1.dylib` contains both `arm64` and `arm64e` slices (for Apple Silicon PAC compatibility).

**Shared memory** (`/tmp/libfaketime-*`) synchronizes faked time across processes spawned by the wrapper.

## Key Conventions

- **C standard**: gnu99 (`-std=gnu99`)
- **Indentation**: 2 spaces, no tabs. Opening/closing braces on their own lines.
- **Naming**: `under_score_case` for functions and variables. Prefix internal/helper functions with `ft_` or `fake_`.
- **Debug output**: Wrap in `#ifdef DEBUG`. Runtime user messages must be prefixed with `"libfaketime"` or make the source obvious.
- **macOS interception**: Functions intercepted via DYLD interpose must be named `macos_<funcname>` and `#ifdef MACOS_DYLD_INTERPOSE`. The actual interpose happens in `do_macos_dyld_interpose()` at the bottom of `libfaketime.c`.
- **Recursion guard**: `DONT_FAKE_TIME(call)` macro sets a thread-local `dont_fake` flag to prevent infinite recursion when calling the real function.
- **Backward compatibility**: Do not break existing behavior. Wrap platform-specific code in `#ifdef __APPLE__` / `#ifndef __APPLE__`.
- **New features**: Must include tests in `test/timetest.c` or functional tests in `test/functests/test_*.sh`. Update `NEWS`, `README`, and `README.OSX` when modifying user-facing functionality.
- **Compiler**: Linux defaults to `gcc`, macOS defaults to `clang`. Compiler is auto-detected in the Makefile.
- **CI**: GitHub Actions runs `make test` on `ubuntu-latest` and `ubuntu-22.04` only (no macOS CI). Uses `-DFORCE_MONOTONIC_FIX`.

## Testing Framework

- **`test/timetest.c`**: C unit tests — add assertions and recompile
- **`test/functests/test_*.sh`**: Functional tests using the bash testframe. Each script defines a `run()` function that calls `run_testcase`. Use `asserteq` / `assertneq` from `testframe.inc`. Cross-platform helpers (like `fakecmd()`) are in `functests/common.inc`.
- **`test/snippets/`**: Small C programs tested for behavior under different FAKETIME configurations

## Adding a New Intercepted Function

1. Pick the right section in `libfaketime.c` (grouped by functionality)
2. Declare a `real_*` function pointer, resolve it with `dlsym(RTLD_NEXT, "name")` in `ftpl_init()`
3. Write the interception: call real → fake → return. Use `DONT_FAKE_TIME()` for the real call.
4. On macOS: add a `macos_<name>` wrapper and a `DYLD_INTERPOSE` entry in `do_macos_dyld_interpose()`
5. Add compile-time guard (`#ifdef FAKE_<FEATURE>`) if the interception is optional
