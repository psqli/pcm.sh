// 2020-08-17
// 2020-08-22 rewritten
//
// usage: ioctl <driver> <function_number> [<value> | <size> r,w]
//
//   driver:      E.g. 65 for ALSA PCM subsystem.
//   function:    Number of the operation to be called on device.
//   value:       If no argument follows value, value is passed to ioctl
//                instead of a pointer to buffer (read about size below).
//   size:        Size of the buffer read from stdin and written to ioctl
//                and/or read from ioctl and written to stderr. The next
//                argument must be 'r' (for reading from ioctl) and/or 'w'
//                (for writing to ioctl).
//
// See the following page for information regarding the parameters above:
//
//   https://kernel.org/doc/html/v5.7/userspace-api/ioctl/ioctl-decoding.html
//
// Ricardo Biehl Pasquali

#include <errno.h>     // errno
#include <stdlib.h>    // atoi(), calloc()
#include <sys/ioctl.h> // ioctl()
#include <unistd.h>    // read(), write()

void read_all(int fd, void *buf, size_t count) {
	int r; while ((r = read(fd, buf, count)) > 0) { buf += r; count -= r; }
}

int main(int argc, char **argv)
{
	argv++; argc--;
	if (argc < 2)
		return 1;

	unsigned long rw, size, driver, function;

	rw       = 0;
	size     = 0;
	driver   = atoi(*argv) & 0xff; argv++; argc--;
	function = atoi(*argv) & 0xff; argv++; argc--;

	void *arg = NULL;

	if (argc == 1) {
		arg = (void*) atol(*argv); argv++; argc++;
	} else if (argc > 1) {
		size = atoi(*argv) & 0x3fff; argv++; argc--;
		rw   = (*argv)[0] + (*argv)[1] == 'r' + 'w' ? 0x3 :
		       (*argv)[0] == 'r' ? 0x2 : 0x1;

		arg = calloc(1, size);
	}

	unsigned long request = rw << 30 | size << 16 | driver << 8 | function;
	int ret;

	// Read buffer from stdin if writing to ioctl
	if (rw & 0x1)
		read_all(0, arg, size);

	// Call ioctl() system call
	ret = ioctl(1, request, arg);
	if (ret < 0)
		ret = errno;

	// Write buffer to stderr if reading from ioctl
	if (rw & 0x2)
		write(2, arg, size);

	return ret;
}
