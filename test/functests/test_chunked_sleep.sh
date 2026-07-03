# Checks that mid-sleep rate changes via FAKETIME_TIMESTAMP_FILE
# affect the remaining sleep duration.
#
# Scenario:
#   1. Start a process with `+0 x1` (normal speed), it calls sleep(10)
#   2. After 1.5s, change config to `+0 x10` (10x speed)
#   3. The sleep should complete in ~2.5s total real time,
#      not 10s (which would happen without chunked sleep).
#
# With 100ms chunks:
#   - 1.5s at 1x  = 1.5 fake seconds elapsed (15 chunks)
#   - 8.5 fake seconds remaining at 10x = 0.85s real time
#   - Total expected: ~2.35s real time

init()
{
    typeset testsuite="$1"
    PLATFORM=$(platform)
    if [ -z "$PLATFORM" ]; then
        echo "$testsuite: unknown platform! quitting"
        return 1
    fi
    echo "# PLATFORM=$PLATFORM"
    return 0
}

run()
{
    init
    run_testcase chunked_sleep_rate_change
}

chunked_sleep_rate_change()
{
    typeset config_file="/tmp/test_chunked_sleep_$$.rc"
    typeset helper_bin="/tmp/sleep_elapsed_$$"

    # Build the test helper (tests run from the test/ directory)
    typeset snippet_src="snippets/sleep_elapsed.c"
    if [ "$PLATFORM" = "mac" ]; then
        cc -o "$helper_bin" "$snippet_src"
    else
        cc -o "$helper_bin" "$snippet_src" -lrt
    fi

    if [ ! -x "$helper_bin" ]; then
        echo "Bail out! Could not build sleep_elapsed helper"
        return 1
    fi

    # Start with normal speed (1x)
    echo "+0 x1" > "$config_file"

    # Run the helper with faketime pointing to our config file
    typeset fakelib
    if [ "$PLATFORM" = "mac" ]; then
        fakelib="$PWD/../src/libfaketime.1.dylib"
        export DYLD_INSERT_LIBRARIES="$fakelib"
        export DYLD_FORCE_FLAT_NAMESPACE=1
    else
        fakelib="$PWD/../src/libfaketime.so.1"
        export LD_PRELOAD="$fakelib"
    fi

    FAKETIME_TIMESTAMP_FILE="$config_file" \
    FAKETIME_DONT_FAKE_MONOTONIC=1 \
    "$helper_bin" > /tmp/sleep_elapsed_output_$$.txt 2>&1 &
    typeset helper_pid=$!

    # Wait for the helper to start and enter sleep
    sleep 1.5

    # Verify helper is still running (still sleeping)
    if ! kill -0 "$helper_pid" 2>/dev/null; then
        echo "Bail out! Helper exited before config change"
        rm -f "$config_file" "$helper_bin" /tmp/sleep_elapsed_output_$$.txt
        return 1
    fi

    # Change rate to 10x
    echo "+0 x10" > "$config_file"

    # Wait for helper to finish (with timeout)
    typeset waited=0
    while kill -0 "$helper_pid" 2>/dev/null && [ "$waited" -lt 30 ]; do
        sleep 0.5
        waited=$((waited + 1))
    done

    if kill -0 "$helper_pid" 2>/dev/null; then
        kill "$helper_pid" 2>/dev/null
        echo "Bail out! Helper did not finish within 15 seconds"
        rm -f "$config_file" "$helper_bin" /tmp/sleep_elapsed_output_$$.txt
        return 1
    fi

    wait "$helper_pid" 2>/dev/null

    # Parse elapsed time from output
    typeset elapsed
    elapsed=$(grep '^ELAPSED=' /tmp/sleep_elapsed_output_$$.txt | cut -d= -f2)

    if [ -z "$elapsed" ]; then
        echo "Bail out! Could not parse ELAPSED from output"
        cat /tmp/sleep_elapsed_output_$$.txt
        rm -f "$config_file" "$helper_bin" /tmp/sleep_elapsed_output_$$.txt
        return 1
    fi

    echo "# Real elapsed time: ${elapsed}s"

    # With chunked sleep: ~1.5s at 1x + 0.85s at 10x ≈ 2.35s
    # Without chunked sleep: full 10s at 1x = 10s
    # We check it's under 5s to clearly distinguish chunked vs non-chunked
    typeset elapsed_int
    elapsed_int=$(echo "$elapsed" | awk '{printf "%d", $1}')

    asserteq 1 $(echo "$elapsed < 5.0" | bc -l) \
        "Elapsed time ${elapsed}s should be < 5s (chunked sleep working)"

    # Also verify it's not instant (should be > 0.5s)
    asserteq 1 $(echo "$elapsed > 0.5" | bc -l) \
        "Elapsed time ${elapsed}s should be > 0.5s (actual sleep happened)"

    rm -f "$config_file" "$helper_bin" /tmp/sleep_elapsed_output_$$.txt
}
