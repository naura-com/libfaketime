# libfaketime-specific common support routines for tests

# say which *_fakecmd wrapper to use
platform()
{
	# may want to expand the pattern for linuxlike
	typeset out=$(uname)
	case "$out" in
	*Darwin*) echo "mac" ;;
	*Linux*) echo "linuxlike" ;;
    GNU|GNU/kFreeBSD) echo "linuxlike" ;;
        *SunOS*) echo "sunos" ;;
	*) echo 1>&2 unsupported platform, uname=\"$out\" ;;
	esac
}

# run faked command on a mac
# UNTESTED
mac_fakecmd()
{
	typeset timestring="$1"; shift
	typeset fakelib=../src/libfaketime.1.dylib
	export DYLD_INSERT_LIBRARIES=$fakelib
	export DYLD_FORCE_FLAT_NAMESPACE=1
	FAKETIME="$timestring" \
	"$@"
}

sunos_fakecmd()
{
        typeset timestring="$1"; shift
        typeset fakelib=../src/libfaketime.so.1
        export LD_PRELOAD=$fakelib
        FAKETIME="$timestring" \
        "$@"
}

# run faked command on linuxlike OS
linuxlike_fakecmd()
{
	typeset timestring="$1"; shift
	FTPL="${FAKETIME_TESTLIB:-../src/libfaketime.so.1}"
	typeset fakelib="$FTPL"
	export LD_PRELOAD=$fakelib
	FAKETIME="$timestring" \
	"$@"
}

# run a command with libfaketime using the given timestring
fakecmd()
{
	${PLATFORM}_fakecmd "$@"
}

# Cross-platform file mtime setter.
# Usage: set_file_mtime <file> <epoch> [<fractional_seconds>]
#   epoch: Unix timestamp (integer seconds)
#   fractional_seconds: optional, e.g. "005" for 5 milliseconds
set_file_mtime()
{
	typeset file="$1"
	typeset epoch="$2"
	typeset frac="${3:-}"

	if [ "$PLATFORM" = "mac" ]; then
		if [ -n "$frac" ]; then
			python3 -c "import os; t=$epoch.${frac}; os.utime('$file', (t, t))"
		else
			python3 -c "import os; os.utime('$file', ($epoch, $epoch))"
		fi
	else
		if [ -n "$frac" ]; then
			touch -d "@${epoch}.${frac}" "$file"
		else
			touch -d "@$epoch" "$file"
		fi
	fi
}

# generate a sequence of numbers from a to b
range()
{
	typeset a=$1 b=$2
	typeset i=$a
	while ((i <= b)); do
		echo $i
		((i = i+1))
	done
}
