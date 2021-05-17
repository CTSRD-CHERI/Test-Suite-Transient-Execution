LLVM = riscv64-unknown-freebsd-clang
LLVM_OBJDUMP = riscv64cheri-objdump

LLVM_OPTS = -Wall -march=rv64imafdcxcheri -mabi=l64pc128 -mno-relax -mcmodel=medany -static -nostdlib -nostartfiles -fno-common -fno-builtin-printf
RISCV_LINK = -T../env/riscv_link.ld
CHERI_LINK = -T../env/cheri_link.ld
OBJDUMP_OPTS = --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data --section=.acode --section=.auipccode --section=.sand0 --section=.sand1 --section=.sand2 --section=.kernel --section=.user --section=.kernel_btb_s --section=.kernel_btb_u

RISCV_SOURCES = $(wildcard riscv_sources/*.S)
CHERI_SOURCES = $(wildcard cheri_sources/*.S)

RISCV_DUMP_FILES = $(patsubst %.S,$(BUILDDIR)/%.dump,$(RISCV_SOURCES))
CHERI_DUMP_FILES = $(patsubst %.S,$(BUILDDIR)/%.dump,$(CHERI_SOURCES))

BUILDDIR = build

.PHONY: all
all: $(BUILDDIR) riscv cheri

build:
	mkdir $@

.PHONY: riscv
riscv: $(RISCV_DUMP_FILES)

.PHONY: cheri
cheri: $(CHERI_DUMP_FILES)

.SECONDARY:
$(BUILDDIR)/riscv_sources/%.out: %.S 
	$(LLVM) $(LLVM_OPTS) $(RISCV_LINK) $< -o $@

.SECONDARY:
$(BUILDDIR)/cheri_sources/%.out: %.S 
	$(LLVM) $(LLVM_OPTS) $(CHERI_LINK) $< -o $@

%.dump: %.out
	$(LLVM_OBJDUMP) $(OBJDUMP_OPTS) $< > $@