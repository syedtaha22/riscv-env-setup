.PHONY: all clean

all: compile
	python3 pyshm.py

compile:
	mkdir -p build/exe
	riscv32-unknown-elf-gcc -march=rv32gcv -mabi=ilp32f -T ../veer/link.ld -o build/exe/rvshm.exe rvshm.s -nostartfiles -lm

clean:
	rm -rf build
