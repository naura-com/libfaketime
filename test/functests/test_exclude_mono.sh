# Checks that setting FAKETIME_DONT_FAKE_MONOTONIC actually prevent
# libfaketime from faking monotonic clocks.
#
# We do this by freezing time at a specific and arbitrary date with faketime,
# and making sure that if we set FAKETIME_DONT_FAKE_MONOTONIC to 1, calling
# clock_gettime(CLOCK_MONOTONIC) returns two different values.
#
# We also make sure that if we don't set FAKETIME_DONT_FAKE_MONOTONIC to 1,
# in other words when we use the default behavior, two subsequent calls to
# clock_gettime(CLOCK_MONOTONIC) do return different values.

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

    run_testcase dont_fake_mono
    # run_testcase fake_mono
}

get_token()
{
    string=$1
    token_index=$2
    separator=$3

    echo $string | cut -d "$separator" -f $token_index
}

assert_timestamps_neq()
{
    timestamps=$1
    msg=$2

    first_timestamp=$(get_token "${timestamps}" 1 ' ')
    second_timestamp=$(get_token "${timestamps}" 2 ' ')

    assertneq "${first_timestamp}" "${second_timestamp}" "${msg}"
}

assert_timestamps_eq()
{
    timestamps=$1
    msg=$2

    first_timestamp=$(get_token "${timestamps}" 1 ' ')
    second_timestamp=$(get_token "${timestamps}" 2 ' ')

    asserteq "${first_timestamp}" "${second_timestamp}" "${msg}"
}

get_monotonic_time()
{
    dont_fake_mono=$1; shift;
    clock_id=$1; shift;
    cat > /tmp/libfaketime_mono_helper.c << 'CEOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <time.h>
#include <unistd.h>
int main() {
    struct timespec ts1, ts2;
    clock_gettime(CLOCK_MONOTONIC, &ts1);
    printf("%lld.%09ld\n", (long long)ts1.tv_sec, ts1.tv_nsec);
    sleep(1);
    clock_gettime(CLOCK_MONOTONIC, &ts2);
    printf("%lld.%09ld\n", (long long)ts2.tv_sec, ts2.tv_nsec);
    return 0;
}
CEOF
    if [ "$PLATFORM" = "mac" ]; then
        gcc -o /tmp/libfaketime_mono_helper /tmp/libfaketime_mono_helper.c
    else
        gcc -o /tmp/libfaketime_mono_helper /tmp/libfaketime_mono_helper.c -lrt
    fi
    FAKETIME_DONT_FAKE_MONOTONIC=${dont_fake_mono} \
    fakecmd "2014-07-21 09:00:00" \
    /tmp/libfaketime_mono_helper
    rm -f /tmp/libfaketime_mono_helper /tmp/libfaketime_mono_helper.c
}

dont_fake_mono()
{
    timestamps=$(get_monotonic_time 1 CLOCK_MONOTONIC)
    msg="When not faking monotonic time, timestamps should be different"
    assert_timestamps_neq "${timestamps}" "${msg}"
}

fake_mono()
{
    timestamps=$(get_monotonic_time 0 CLOCK_MONOTONIC)
    msg="When faking monotonic, timestamps should be equal"
    assert_timestamps_eq "${timestamps}" "${msg}"
}
