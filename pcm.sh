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

invert_bytes() {
	i=${#1}
	while [ $i -gt 0 ]; do
		i=$[$i-2]
		echo -n ${1:$i:2}
	done
}

to_hex() {
	invert_bytes $(printf "%08x" $1)
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

# Convert parameters to hexadecimal
# =================================

bits_per_sample="$(to_hex $bits_per_sample)"
channels="$(to_hex $channels)"
rate="$(to_hex $rate)"

# Prepare hardware parameters buffer
# ==================================

# Initialize buffer to empty string
buf="$(get_hwparams_initialized)"

# sets the access mode to Read/Write Interleaved
val="0800000000000000000000000000000000000000000000000000000000000000"
buf=$(echo "$buf" | sed "2s/.*/$val/")

# Set bits per sample
val="$bits_per_sample"
buf=$(echo "$buf" | sed "10s/[0-9a-fA-F]\{16\}/$val$val/")

# Set channels
val="$channels"
buf=$(echo "$buf" | sed "12s/[0-9a-fA-F]\{16\}/$val$val/")

# Set rate
val="$rate"
buf=$(echo "$buf" | sed "13s/[0-9a-fA-F]\{16\}/$val$val/")

# Set hardware parameters
echo "$buf" | xxd -r -p - | ./ioctl $ALSA_DRIVER $HW_PARAMS 608 rw 2>/dev/null

# Prepare device
./ioctl $ALSA_DRIVER $PREPARE

cat

# Wait for PCM buffer to drain
./ioctl $ALSA_DRIVER $DRAIN
