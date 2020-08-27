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

# Initialize buffer to empty string
buf="$(get_hwparams_initialized)"

# sets the access mode to Read/Write Interleaved
val="0800000000000000000000000000000000000000000000000000000000000000"
buf=$(echo "$buf" | sed "2s/.*/$val/")

# sets bits per sample to 16
val="10000000"
buf=$(echo "$buf" | sed "10s/[0-9a-fA-F]\{16\}/$val$val/")

# sets channels to 2
val="02000000"
buf=$(echo "$buf" | sed "12s/[0-9a-fA-F]\{16\}/$val$val/")

# sets rate to 44100
val="44ac0000"
buf=$(echo "$buf" | sed "13s/[0-9a-fA-F]\{16\}/$val$val/")

# Set hardware parameters
! echo "$buf" \
| xxd -r -p - \
| ./ioctl $ALSA_DRIVER $HW_PARAMS 608 rw 2>/dev/null

# Prepare device
./ioctl $ALSA_DRIVER $PREPARE

cat

# Wait for PCM buffer to drain
./ioctl $ALSA_DRIVER $DRAIN
