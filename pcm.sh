#!/bin/sh
#
# 2020-08-14
#
# usage: cat sound_file | pcm.sh >/dev/snd/pcmC0D0p
#
# Ricardo Biehl Pasquali

main() {
	# Default parameters
	bits_per_sample=16
	channels=2
	rate=44100

	debug=false

	# Read command line options
	while getopts b:c:dr: name; do
		case $name in
			b) bits_per_sample="$OPTARG";;
			c) channels="$OPTARG";;
			r) rate="$OPTARG";;
			d) debug=true;;
			?) printf "Usage: %s: [-b sample_bits] [-c channels] [-r rate]\n" $0
			exit 2;;
		esac
	done
	shift $(($OPTIND - 1))

	# If debug is true, print hardware parameters
	if $debug; then get_hwparams | xxd; exit 0; fi

	# Set hardware parameters
	get_hwparams | ./ioctl $ALSA_DRIVER $HW_PARAMS 608 rw 2>/dev/null

	# Prepare device
	./ioctl $ALSA_DRIVER $PREPARE

	cat

	# Wait for PCM buffer to drain
	./ioctl $ALSA_DRIVER $DRAIN
}

# Binary output helpers
# ==============================================================================

# little-endian by default
print_bytes() (
	bits=$1; val=$2; if [ -z $val ]; then val=0; fi
    i=0; while [ $i -lt $bits ]; do
        printf "%b" $(printf "\\%o" $((($val >> i) & 0xff))); i=$((i+8))
    done
)
s8()  { print_bytes 8  $1; }
s16() { print_bytes 16 $1; }
s32() { print_bytes 32 $1; }

# ALSA helpers
# ==============================================================================

ALSA_DRIVER="65" # numerical value for character 'A'
HW_REFINE="17" HW_PARAMS="17" PREPARE="64" DRAIN="68"

mask() { s32 $1; s32; s32; s32; s32; s32; s32; s32; }
mask_val() { mask $((1 << $1)); }
mask_any() { mask $((~0)); }

interval() { s32 $1; s32 $2; s32; }
interval_val() { interval $1 $1; }
interval_any() { interval 0 $((~0)); }

# The order of commands does matter
get_hwparams() {
	s32 # hwparams flags

	mask_val 3 # Access type
	mask_any # Format
	mask_any # Subformat

	i=5; while [ $((i--)) -gt 0 ]; do mask_any; done

	interval_val $bits_per_sample # Sample bits
	interval_any # Frame bits
	interval_val $channels # Channels
	interval_val $rate # Rate
	interval_any # Period time (us)
	interval_any # Period size (frames)
	interval_any # Period bytes
	interval_any # Periods
	interval_any # Buffer time (us)
	interval_any # Buffer size (frames)
	interval_any # Buffer bytes
	interval_any # Tick time (us)

	i=9; while [ $((i--)) -gt 0 ]; do interval_any; done

	# fill remaining integers
	i=24; while [ $((i--)) -gt 0 ]; do s32; done
}

main $@
