# Test-Suite-Transient-Execution

This repo contains all major transient-execution attacks in both RISC-V and CHERI-RISC-V
assembly. Execute the following commands to build the assembly tests

```
$ make # build all tests
$ make riscv # build only the RISC-V tests
$ make cheri # build only the CHERI-RISC-V tests
```

In order to build the tests you will have to download and build CHERI LLVM [(https://github.com/CTSRD-CHERI/llvm-project](https://github.com/CTSRD-CHERI/llvm-project)). All tests are currently tailored to Toooba ([https://github.com/CTSRD-CHERI/Toooba](https://github.com/CTSRD-CHERI/Toooba)) -- a processor based on RiscyOO implementing both RISC-v and CHERI-RISC-V.