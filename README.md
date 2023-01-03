pcm.sh
======

`pcm.sh` forwards data from stdin to stdout. **If stdout is a PCM device it is
set up.**

	usage: pcm.sh [-b <sample_bits>] [-c <channels>] [-r <rate>]

The following example outputs input_file to PCM device Card 0 Device 0:

	cat input_file | pcm.sh > /dev/snd/pcmC0D0

The default parameters are 16-bit sample resolution, 2 samples per frame
(i.e. channels), 44100 frames per second (i.e. rate).

ioctl
=====

There is no standard method for calling ioctl() system call from a shell
script. `ioctl.c` is essentially a wrapper for the system call.

Compile it using:

	gcc -Wall -o ioctl ioctl.c

It should not display any warnings or errors.

For how to use ioctl, see `ioctl.c`. It's very small.

Notes of the implementation:

When read flag is defined after size parameter, the buffer is written to
stderr after being processed by ioctl regardless of the return value. The
buffer is the same filled with data from stdin if write flag is set.

If `ioctl()` fails its error number (errno) is returned as the exit status
of the program. If ioctl return positive value, there is no straightforward
way to know whether the return value corresponds to an error.


POSIX compliance
================

`pcm.sh` shall be fully POSIX-compliant. Here are some notes of issues that have
caused or may cause confusion:

- The `%b` conversion specifier for the `printf` is supported according to item
  7 in the "EXTENDED DESCRIPTION" section of the [printf utility spec](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/printf.html).

- The section "2.6.4 Arithmetic Expansion" of the [POSIX shell specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
  states that both the prefix and postfix operators are not required to be
  implemented by the shell. The script used one of these operators, but this was
  fixed by 03f3ac3297dc1474d5954e03de99e102026200de

- The `xxd` tool (which is not part of POSIX) is used for debugging purposes,
  and is called only when the debug option is specified.
