# RISC-V and Python Shared Memory Communication via QEMU

This guide demonstrates inter-process communication (IPC) between Python and RISC-V code running in QEMU using shared memory. The example includes a lock-based synchronization mechanism for safe data exchange.

-----

## Table of Contents

1. [Introduction to Shared Memory](#1-introduction-to-shared-memory)
2. [How It Works](#2-how-it-works)
3. [Installing QEMU](#3-installing-qemu)
4. [Compilation and Execution](#4-compilation-and-execution)
5. [Automation with Make](#5-automation-with-make)
6. [Note](#6-note)
7. [Acknowledgements](#7-acknowledgements)

-----

## 1. Introduction to Shared Memory

Shared memory is a method of inter-process communication (IPC) where two or more processes access a common memory region. This approach provides:

- **High Performance**: Direct memory access without kernel syscalls (after initial setup)
- **Simplicity**: Easy to implement for basic synchronization patterns
- **Flexibility**: Works between processes running on the same machine

In this example, Python acts as the "coordinator" process while a RISC-V program compiled to an executable runs inside QEMU. They communicate via a memory-mapped file on disk.

### Use Cases

- Real-time data exchange between simulations and control logic
- Rapid prototyping of embedded systems with host-side processing
- Testing RISC-V algorithms with Python data validation

-----

## 2. How It Works

The communication follows a simple **lock-based protocol**:

### Memory Layout

```
[Bytes 0-3]:   Lock Flag (int32)
               0 = Python can write, RISC-V can read
               1 = RISC-V finished writing, Python should read
               
[Bytes 4+]:    Data Payload (floats or custom data)
```

### Synchronization Protocol

1. **RISC-V waits** until lock == 0 (Python released it)
2. **RISC-V writes** data to shared memory (bytes 4 onwards)
3. **RISC-V sets** lock = 1 (signals Python: "data ready")
4. **Python waits** until lock == 1 (RISC-V finished)
5. **Python reads** the data
6. **Python sets** lock = 0 (signals RISC-V: "ready for more")
7. **Repeat** from step 1

### Memory Fences

The code uses memory fence instructions (`fence w,w` and `fence w,r`) to ensure visibility across CPU cores and prevent memory reordering bugs.

-----

## 3. Installing QEMU

QEMU must be installed with user-mode static binaries for RISC-V emulation.

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install qemu-user-static
```

### Fedora/Red Hat

```bash
sudo dnf install qemu-user-static
```

### Arch Linux

```bash
sudo pacman -S qemu-user-static
```

### Verify Installation

```bash
which qemu-riscv32-static
```

If installed correctly, it will show the path to the executable.

-----

## 4. Compilation and Execution

This section walks through the build process step-by-step.

### Prerequisites

Ensure you have the RISC-V GNU toolchain installed:

```bash
riscv32-unknown-elf-gcc --version
```

### Step 1: Create Build Directory Structure

```bash
mkdir -p build/exe
```

### Step 2: Compile the RISC-V Assembly

```bash
riscv32-unknown-elf-gcc -march=rv32gcv -mabi=ilp32f -T ../veer/link.ld \
  -o build/exe/rvshm.exe rvshm.s -nostartfiles -lm
```

**Flags explained:**
- `-march=rv32gcv`: RV32 architecture with G (standard), C (compressed), and V (vector) extensions
- `-mabi=ilp32f`: 32-bit ABI with hardware floating-point
- `-T ../veer/link.ld`: Use the linker script from `veer/` (Update path if needed)
- `-nostartfiles`: Don't link default startup code
- `-lm`: Link math library

### Step 3: Run the Shared Memory System

```bash
python3 pyshm.py
```

This will:
1. Initialize a shared memory file at `build/shared.mem` (4 KB)
2. Launch the RISC-V executable in QEMU
3. Exchange data for 100 iterations
4. Display received floats
5. Clean up and exit

### Expected Output

```
[Python] Starting RISC-V process...
[Python] Iteration 0: Received 100 floats
[Python] First 5 values: [1.0, 2.0, 3.0, 4.0, 5.0]
[Python] Iteration 1: Received 100 floats
...
[Python] Cleaning up...
[Python] Done
```

-----

## 5. Automation with Make

The provided `Makefile` automates compilation and execution.

### Basic Usage

**Compile and run:**
```bash
make
```

This single command:
- Creates the `build/` directory structure
- Compiles `rvshm.s` using the RISC-V toolchain
- Launches `pyshm.py` to start communication

**Clean up:**
```bash
make clean
```

This removes all generated files:
- The `build/` directory and all contents
- The `build/shared.mem` file (if created)

-----

## 6. Note

This is an example setup demonstrating the concept of inter-process communication between Python and RISC-V code. Feel free to integrate it into your projects and tweak it as needed for your specific use case.

-----

## 7. Acknowledgements

**Code and design by:** [Hamza Ahmed (Witherthrottle)](https://github.com/Witherthrottle)

- `rvshm.s`: RISC-V assembly implementation with vector instructions
- `pyshm.py`: Python coordinator and data reader