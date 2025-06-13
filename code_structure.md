---

# Code Structure Explained

This document provides a detailed explanation of the required code structure for your RISC-V assembly projects within this repository, particularly focusing on the roles of `link.ld` and `whisper.json`. Understanding these files and conventions is essential before using the `build.sh` script to compile and simulate your code.

---

## 1. RISC-V Assembly File Structure (`.s` files)

When writing your RISC-V assembly code, there's a common structure and a few crucial elements you'll need to include for proper compilation and simulation with VeeR-ISS (`whisper`).

Here's the general structure and an explanation of its key parts:

```assembly
# Neccessary For VEER-ISS/whisper
#define STDOUT 0xd0580000

.section .text
.global _start  # _start is mandatory for the linker to know where to start execution, basically like main() in C/C++
_start:

    # Your RISC-V assembly instructions go here.
    # This is where your program's main logic resides.


# Necessary for VeeR-ISS/whisper to stop execution
_finish:
    li x3, 0xd0580000    # Load the memory-mapped I/O address for STDOUT
    addi x5, x0, 0xff    # Load a termination value (e.g., 0xff)
    sb x5, 0(x3)         # Store the termination value to the STDOUT address
    beq x0, x0, _finish  # Infinite loop to halt simulation
.rept 100
    nop                  # No-operation instructions to ensure simulator catches the halt
.endr

# .data section if needed
.data
    # You can define initialized data here, like variables or arrays.
    # For example:
    # my_variable: .word 10
    # my_array:    .float 1.0, 2.0, 3.0

    # You can also reserve uninitialized space using .space:
    # result_buffer: .space 80 # Allocates 80 bytes for a buffer
```

### Explanation of Key Components:

* **`#define STDOUT 0xd0580000`**:
    This line defines a **symbolic constant `STDOUT`** that points to a specific memory address (`0xd0580000`). This address is where the VeeR-ISS simulator (`whisper`) expects to receive data for output, such as program termination signals. You'll typically use this constant in your assembly code to signal the end of your program's execution to the simulator.

* **`.section .text`**:
    This directive marks the beginning of the **text segment**, which contains your program's executable instructions. All your RISC-V assembly instructions should be placed within this section.

* **`.global _start` / `_start:`**:
    The **`_start` label** is the mandatory entry point for your program. The linker needs this global symbol to know where to begin execution. It functions similarly to the `main()` function in C/C++ programs. Your main program logic will follow this label.

* **`_finish:` Label and Exit Sequence**:
    For the VeeR-ISS simulator (`whisper`) to terminate gracefully, your program needs to include a specific exit sequence. The `_finish` label provides a convenient target for your program to jump to when its execution is complete. The sequence shown, which writes `0xff` to the `STDOUT` address, is how `whisper` detects that the program has finished. The `bnez x0, x0, _finish` creates an infinite loop to halt the processor, and the subsequent `nop` instructions ensure the simulator has enough cycles to register the termination condition.

* **`.data` Section**:
    This optional section is where you declare and initialize any global or static data your program needs. This can include variables, arrays, or buffers. You can also use the `.space` directive here to reserve uninitialized memory.

---

## 2. Linker Script (`veer/link.ld`)

The `link.ld` file is the **linker script** for your RISC-V project. It provides instructions to the GNU linker (`riscv32-unknown-elf-ld`) on how to arrange different sections of your compiled code and data into the final executable binary. It ensures that your program components are correctly placed in the simulator's memory space.

Here's the content of the `link.ld` file:

```ld
OUTPUT_ARCH( "riscv" )
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text.init .  : { *(.text.init) }

  .text . : { *(.text) }
  _end = .;
  . = 0xd0580000;
  .data.io .  : { *(.data.io) }
    . = 0xf0040000 ;
  .data  :  ALIGN(0x800) { *(.*data) *(.rodata*) STACK = ALIGN(16) + 0x8000; }
  .bss : { *(.bss) }

    . = 0xfffffff8; .data.ctl : { LONG(0xf0040000); LONG(STACK) }
}
```

### Explanation of Key Directives:

* **`OUTPUT_ARCH( "riscv" )`**: Specifies that the generated executable is designed for the RISC-V architecture.
* **`ENTRY(_start)`**: Explicitly tells the linker that program execution should start at the `_start` label, aligning with the `_start` label in your assembly code.
* **`SECTIONS { ... }`**: This block defines the memory layout of your program.
    * **. = `0x80000000`**: Sets the starting memory address for the first section to `0x80000000`. This is typically the base address where your executable code will be loaded in the simulator.
    * **`.text.init` and `.text`**: These sections contain your executable instructions. Your assembly code (within `.section .text`) will be placed here.
    * `_end = .`: A symbol `_end` is defined at the current memory address, often used to mark the end of the code sections.
    * **. = `0xd0580000`**: This address is specifically designated for **memory-mapped I/O**.
    * **`.data.io`**: This section is for data related to I/O operations, such as the `STDOUT` address used for simulator communication.
    * **. = `0xf0040000`**: Sets the starting address for your main data segments.
    * **`.data`**: This is where your initialized global and static data (defined using `.data` in your assembly) will be placed. `ALIGN(0x800)` ensures it starts on an 0x800-byte boundary.
    * `STACK = ALIGN(16) + 0x8000;`: Defines the initial location of the stack pointer.
    * **`.bss`**: Contains uninitialized global and static data. This memory is typically zeroed out before your program begins execution.
    * **. = `0xfffffff8`; .data.ctl : { LONG(`0xf0040000`); LONG(STACK) }**: These lines set up control data, which can be used by the simulator for internal memory management or to define pointers to important memory regions like the stack.

In essence, `link.ld` acts as a blueprint, guiding the linker to correctly position your code and data in the simulator's virtual memory, enabling proper program execution and interaction with the simulated hardware environment.

---

## 3. Simulator Configuration (`veer/whisper.json`)

The `whisper.json` file is a crucial configuration file for the `whisper` simulator (part of VeeR-ISS). It defines the virtual hardware environment and various parameters that influence how your RISC-V code will be simulated.

Here's an explanation of the parameters found in the `whisper.json` file:

```json
{
    "xlen": 32,
    "enable_zfh": "true",
    "enable_zba": "true",
    "enable_zbb": "true",
    "abi_names": "true",
    "csr": {
        "misa": {
            "reset-comment": "imabfcv",
            "reset": "0x40201126",
            "mask-comment": "Misa is not writable by CSR instructions",
            "mask": "0x0"
        },
        "mstatus": {
            "mstatus-comment": "Hardwired to zero except for FS, VS, and SD.",
            "reset": "0x80006600",
            "mask": "0x0",
            "poke_mask": "0x0"
        }
    },
    "vector": {
        "bytes_per_vec": 32,
        "max_bytes_per_elem": 8
    }
}
```

### Explanation of Parameters:

* **`"xlen": 32`**:
    This sets the **eXtension Length (XLEN)** of the simulated RISC-V architecture to 32 bits, meaning you're simulating a 32-bit RISC-V processor.

* **`"enable_zfh": "true"`**:
    Enables the **Zfh (Half-Precision Floating-Point)** extension. If your assembly code uses half-precision floating-point operations, this must be set to `true`.

* **`"enable_zba": "true"`**:
    Enables the **Zba (Atomic Instructions)** extension. This is part of the standard `A` extension for atomic memory operations, crucial for multithreaded or shared-memory contexts.

* **`"enable_zbb": "true"`**:
    Enables the **Zbb (Bit Manipulation)** extension. This provides a set of instructions for various bitwise operations, which can be very useful for optimizing certain algorithms.

* **`"abi_names": "true"`**:
    When set to `true`, this enables the use of **ABI (Application Binary Interface) register names** (like `a0`, `t0`, `sp`) in the simulator's output logs. This makes the logs much easier to read and debug, as you'll see meaningful register names instead of just numerical register identifiers (`x10`, `x5`, `x2`).

* **`"csr"`**:
    This section is for configuring **Control and Status Registers (CSRs)**. These are special registers that control and query the CPU's operational state.
    * **`"misa"` (Machine ISA Register)**:
        * `"reset-comment": "imabfcv"`: A comment indicating the standard extensions enabled at reset.
        * `"reset": "0x40201126"`: The hexadecimal value that the `misa` register will hold when the simulation starts. This value encodes the enabled ISA extensions (I - Integer, M - Multiply/Divide, A - Atomic, B - Bit Manipulation, F - Single-Precision Float, C - Compressed, V - Vector).
        * `"mask-comment": "Misa is not writable by CSR instructions"`: Explains that `misa` is generally a read-only register.
        * `"mask": "0x0"`: A mask used to control writability; `0x0` means it's not writable through CSR instructions.
    * **`"mstatus"` (Machine Status Register)**:
        * `"mstatus-comment": "Hardwired to zero except for FS, VS, and SD."`: Provides context on the nature of `mstatus`.
        * `"reset": "0x80006600"`: The reset value for `mstatus`. This value contains bits related to the current privilege mode, interrupt enable flags, and the status of the floating-point (`FS`), vector (`VS`), and dirty/present (`SD`) units.
        * `"mask": "0x0"`: A mask for writability.
        * `"poke_mask": "0x0"`: Another mask for specific write operations.

* **`"vector"`**:
    This section is crucial for configuring the **RISC-V Vector Extension** within the simulator.
    * **`"bytes_per_vec": 32`**:
        Sets the **Vector Length (VLEN)** for the simulator. This means each vector register (e.g., `v0`, `v1`) will be 32 bytes (or 256 bits) wide. This parameter determines how many elements of a certain size can fit into a single vector register.
    * **`"max_bytes_per_elem": 8`**:
        Specifies the maximum number of bytes an individual element within a vector can occupy. This means your vector elements can be up to 64-bit (8 bytes).

By properly configuring `whisper.json`, you create a simulated RISC-V environment that precisely matches the architecture and extensions your assembly code is designed for, ensuring accurate and consistent simulation results.