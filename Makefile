LLVM = riscv64-unknown-freebsd-clang
LLVM_OBJDUMP = riscv64cheri-objdump

LLVM_OPTS = -Wall -mno-relax -mcmodel=medany -static -nostdlib -nostartfiles -fno-common -fno-builtin-printf
RISCV_OPTS = -march=rv64imafdc -mabi=lp64 -Tenv/riscv_link.ld
CHERI_OPTS = -march=rv64imafdcxcheri -mabi=l64pc128 -Tenv/cheri_link.ld
OBJDUMP_OPTS = --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data --section=.acode --section=.auipccode --section=.sand0 --section=.sand1 --section=.sand2 --section=.kernel --section=.user --section=.kernel_btb_s --section=.kernel_btb_u

RISCV_SOURCES = $(wildcard riscv_sources/*.S)
CHERI_SOURCES = $(wildcard cheri_sources/*.S)

RISCV_DUMP_FILES = $(patsubst %.S,$(BUILDDIR)/%.dump,$(RISCV_SOURCES))
CHERI_DUMP_FILES = $(patsubst %.S,$(BUILDDIR)/%.dump,$(CHERI_SOURCES))

BUILDDIR = build

.PHONY: all
all: riscv cheri

build:
	mkdir $@
	mkdir -p $@/riscv_sources
	mkdir -p $@/cheri_sources

.PHONY: riscv
riscv: $(BUILDDIR) $(RISCV_DUMP_FILES)

.PHONY: cheri
cheri: $(BUILDDIR) $(CHERI_DUMP_FILES)

.SECONDARY:
$(BUILDDIR)/riscv_sources/%.out: riscv_sources/%.S 
	$(LLVM) $(LLVM_OPTS) $(RISCV_OPTS) $< -o $@

.SECONDARY:
$(BUILDDIR)/cheri_sources/%.out: cheri_sources/%.S 
	$(LLVM) $(LLVM_OPTS) $(CHERI_OPTS) $< -o $@

%.dump: %.out
	$(LLVM_OBJDUMP) $(OBJDUMP_OPTS) $< > $@

.PHONY: clean
clean:
	rm -rf $(BUILDDIR)
