# QNX SDP 8.0, target aarch64le.
# qcc is the SDP driver. gcc_ntoaarch64le selects the aarch64le little-endian toolchain
# (the ntoaarch64-gcc binary). Run this inside the qnx-build container after
# sourcing qnxsdp-env.sh, or from the Mac with scripts/deploy-example.sh.

CC := qcc
QCC_SPEC := gcc_ntoaarch64le

.PHONY: all clean

all: hello-qnx

hello-qnx: hello-qnx.c
	@command -v $(CC) >/dev/null 2>&1 || { \
		echo "qcc is not on PATH. Build inside the qnx-build container: ./scripts/deploy-example.sh"; \
		exit 1; \
	}
	$(CC) -V$(QCC_SPEC) -Wall -o $@ hello-qnx.c

clean:
	rm -f hello-qnx
