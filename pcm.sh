#!/bin/sh
#
# 2020-08-14
#
# usage: cat sound_file | pcm.sh >/dev/snd/pcmC0D0p
#
# Ricardo Biehl Pasquali

ALSA_DRIVER="65" # numerical value for character 'A'
HW_PARAMS="17"
PREPARE="64"
DRAIN="68"

get_hwparams_initialized() {
	# set flags to zero
	i=0; size=1;
	while [ $i -lt $size ]; do
		echo "00000000";
		i=$(( i + 1 ));
	done

	# fill all masks with ones (ffff)
	i=0; size=8;
	while [ $i -lt $size ]; do
		echo "ffffffffffffffffffffffffffffffff" \
		     "ffffffffffffffffffffffffffffffff";
		i=$(( i + 1 ));
	done

	# fill all intervals with full range
	i=0; size=21;
	while [ $i -lt $size ]; do
		echo "00000000ffffffff00000000";
		i=$(( i + 1 ));
	done

	# fill remaining integers
	i=0; size=24;
	while [ $i -lt $size ]; do
		echo "00000000";
		i=$(( i + 1 ));
	done
}

# In hexadecimal format, two characters represent one byte.
# For splitting bytes, just add a newline each two characters :-)
split_bytes ()
{
	fold -w 2
}

# Converts a continuous hexadecimal string from standard input into
# little-endian and writes to standard output.
as_little_endian ()
( # runs in a subshell
	out=""
	for byte in $(split_bytes); do
		out="$byte$out";
	done
	printf "$out"
)

to_hex ()
{
	printf "%08x" $1 | as_little_endian
}

setparam() {
	param_id=$1; min=$(to_hex $2); max=$(to_hex $2)
	sed "${param_id}s/[0-9a-fA-F]\{16\}/${min}${max}/"
}

# Get parameters from command line
# ================================

# Default parameters
bits_per_sample=16
channels=2
rate=44100

while getopts b:c:r: name; do
	case $name in
		b) bits_per_sample="$OPTARG";;
		c) channels="$OPTARG";;
		r) rate="$OPTARG";;
		?) printf "Usage: %s: [-b sample_bits] [-c channels] [-r rate]\n" $0
		   exit 2;;
	esac
done

shift $(($OPTIND - 1))
#printf "Remaining arguments are: %s\n" "$*"

# Prepare hardware parameters buffer
# ==================================

# Initialize buffer to empty string
buf="$(get_hwparams_initialized)"

# sets the access mode to Read/Write Interleaved
val="0800000000000000000000000000000000000000000000000000000000000000"
buf=$(echo "$buf" | sed "2s/.*/$val/")

PARAM_SAMPLE_BITS=10
PARAM_CHANNELS=12
PARAM_RATE=13
buf=$(echo $buf | \
	setparam $PARAM_SAMPLE_BITS $bits_per_sample | \
	setparam $PARAM_CHANNELS    $channels | \
	setparam $PARAM_RATE        $rate )

# Set hardware parameters
echo "$buf" | xxd -r -p - | ./ioctl $ALSA_DRIVER $HW_PARAMS 608 rw 2>/dev/null

# Prepare device
./ioctl $ALSA_DRIVER $PREPARE

cat

# Wait for PCM buffer to drain
./ioctl $ALSA_DRIVER $DRAIN
