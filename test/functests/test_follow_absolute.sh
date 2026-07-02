# Tests for FAKETIME_FOLLOW_ABSOLUTE feature.
#
# When FAKETIME_FOLLOW_ABSOLUTE=1 is set alongside FAKETIME="%" and
# FAKETIME_FOLLOW_FILE, time freezes at the follow file's mtime
# and only advances when the file's mtime changes.

FOLLOW_FILE=".follow_absolute_test_file"

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

	# macOS SIP prevents DYLD_INSERT_LIBRARIES from intercepting system
	# binaries (date, perl). The follow_absolute tests rely on these to
	# verify time faking behavior and cannot run reliably on macOS.
	if [ "$PLATFORM" = "mac" ]; then
		echo "# (skipping, SIP blocks DYLD_INSERT_LIBRARIES for system binaries)"
		return 0
	fi

	run_testcase follow_absolute_basic
	run_testcase follow_absolute_freeze
	run_testcase follow_absolute_tracks_mtime

	rm -f "$FOLLOW_FILE"
}

# Helper to run a command with follow-absolute configuration
follow_absolute_cmd()
{
	FAKETIME_FOLLOW_FILE="$FOLLOW_FILE" \
	FAKETIME_FOLLOW_ABSOLUTE=1 \
	fakecmd "%" "$@"
}

# Test that time matches the follow file's mtime
follow_absolute_basic()
{
	set_file_mtime "$FOLLOW_FILE" 1584268200
	typeset actual
	actual=$(follow_absolute_cmd date -u +"%Y-%m-%d %H:%M:%S")
	asserteq "$actual" "2020-03-15 10:30:00" \
		"time should match follow file mtime"
}

# Test that time stays frozen (does not advance with real time)
follow_absolute_freeze()
{
	set_file_mtime "$FOLLOW_FILE" 1584268200
	typeset timestamps
	timestamps=$(follow_absolute_cmd \
		perl -e 'print time(), "\n"; sleep(2); print time(), "\n"')
	typeset first second
	first=$(echo "$timestamps" | head -1)
	second=$(echo "$timestamps" | tail -1)
	asserteq "$first" "$second" \
		"time should stay frozen within a single process"
}

# Test that time tracks file mtime changes at sub-second precision
follow_absolute_tracks_mtime()
{
	# Check if filesystem supports sub-second mtime
	touch "$FOLLOW_FILE"
	perl -e 'utime 1234567890, 1234567890.500, shift' "$FOLLOW_FILE" 2>/dev/null
	typeset mtime
	mtime=$(perl -e 'my $m = (stat(shift))[9]; print $m' "$FOLLOW_FILE" 2>/dev/null)
	if [ "$mtime" = "1234567890" ]; then
		echo "# (skipping, sub-second mtime not supported on this filesystem)"
		return 0
	fi

	set_file_mtime "$FOLLOW_FILE" 1584268200 000
	typeset first
	first=$(follow_absolute_cmd date +%s.%N)

	set_file_mtime "$FOLLOW_FILE" 1584268200 005
	typeset second
	second=$(follow_absolute_cmd date +%s.%N)

	assertneq "$first" "$second" \
		"time should advance with file mtime (ms precision)"
}
