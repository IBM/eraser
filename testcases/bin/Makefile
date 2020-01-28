abs_top_srcdir := ${ERASER_HOME}/microprobe/targets/riscv/examples
include $(abs_top_srcdir)/Makefrag

include $(src_dir)/tests.d

XLEN := 64
RISCV_PREFIX	?= riscv$(XLEN)-unknown-elf-
RISCV_GCC			?= $(RISCV_PREFIX)gcc
RISCVTOOLS := ${ROCKETTOOLS_HOME}

tests_p = $(addprefix riscv_ipc-p-, $(tests))
tests_v = $(addprefix riscv_ipc-v-, $(tests))

CFLAGS ?= \
	-static \
	-mcmodel=medany \
	-fvisibility=hidden \
	-nostdlib \
	-nostartfiles \
	-I$(abs_top_srcdir) \
	-I$(RISCVTOOLS)

.PHONY: default all clean

default: all

all: $(tests_p)

vpath %.S $(src_dir)

riscv_ipc-p-%: %.S
	$(RISCV_GCC) $(CFLAGS) -I$(ENV_P) -T$(ENV_P)/link.ld -o $@ $<

riscv_ipc-v-%: %.S
	$(RISCV_GCC) $(CFLAGS) -I$(ENV_V) -T$(ENV_V)/link.ld -o $@ $<

junk += $(tests_p) $(tests_v)

clean:
	rm -rf $(junk)
