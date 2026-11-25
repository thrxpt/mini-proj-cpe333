# Out-of-tree build of miniramfs.ko
# KDIR defaults to the build tree of the running kernel; override with e.g.
#   make KDIR=/home/fuse2005/kernel-build/linux-6.8.12
KDIR ?= /lib/modules/$(shell uname -r)/build

obj-m += miniramfs.o

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean

.PHONY: all clean
