# ============================================================================
# ACKNOWLEDGEMENTS
# ============================================================================
# This file was written and provided by Hamza Ahmed (Github: Witherthrottle)
# ============================================================================


# ============================================================================
# SHARED MEMORY COMMUNICATION: RISC-V SIDE
# ============================================================================
# This code demonstrates how to send data to Python using shared memory
# with a simple lock-based synchronization mechanism.
#
# MEMORY LAYOUT:
# [0-3]:     Lock flag (4 bytes, int32)
#            0 = Python's turn to read
#            1 = RISC-V's turn to write
# [4-end]:   Data payload (floats or whatever you need)
#
# LOCK PROTOCOL:
# 1. RISC-V waits until lock == 0 (Python finished reading)
# 2. RISC-V writes data to shared memory
# 3. RISC-V sets lock = 1 (signals Python to read)
# 4. RISC-V waits until lock == 0 again (repeat)
# ============================================================================

.section .data
.align 2

# Configuration
.equ N_FLOATS, 100          # Number of floats to send
.equ MMAP_SIZE, 4096        # Must match Python's FILESIZE

# Your data arrays (example)
my_data:
    .float 1.0, 2.0, 3.0, 4.0, 5.0
    # ... add more floats up to N_FLOATS
    .skip (N_FLOATS - 5) * 4  # Fill rest with zeros

filename: .string "build/shared.mem"

.section .text
.global _start

_start:
    # ====================
    # STEP 1: Open the shared memory file
    # ====================
    li a7, 56               # syscall: openat
    li a0, -100             # AT_FDCWD (current directory)
    la a1, filename         # pointer to filename
    li a2, 66               # O_RDWR | O_CREAT (open for read/write, create if needed)
    li a3, 0644             # permissions: rw-r--r--
    ecall
    mv s0, a0               # s0 = file descriptor
    
    # Check if open failed
    li t0, -1
    beq s0, t0, exit_error
    
    # ====================
    # STEP 2: Memory map the file
    # ====================
    li a7, 222              # syscall: mmap
    li a0, 0                # addr = NULL (let kernel choose)
    li a1, MMAP_SIZE        # length
    li a2, 3                # prot = PROT_READ | PROT_WRITE
    li a3, 1                # flags = MAP_SHARED
    mv a4, s0               # fd (file descriptor)
    li a5, 0                # offset = 0
    ecall
    mv s1, a0               # s1 = base address of shared memory
    
    # Check if mmap failed
    li t0, -1
    beq s1, t0, exit_error

    # ====================
    # MAIN LOOP: Send data repeatedly
    # ====================
main_loop:
    # STEP 3: Wait for Python to finish reading (lock == 0)
    # This is a "spin-lock" - we keep checking until lock becomes 0
wait_for_python:
    lw t0, 0(s1)            # Load lock flag from shared memory
    bnez t0, wait_for_python # If lock != 0, keep waiting
    
    # ====================
    # STEP 4: Write data to shared memory
    # ====================
    # Now lock == 0, so we can write our data
    
    # We'll use vector instructions to copy data efficiently
    la t0, my_data          # t0 = source data address
    mv t1, s1               # t1 = destination (shared memory base)
    addi t1, t1, 4          # Skip the 4-byte lock flag
    li t2, N_FLOATS         # t2 = number of floats remaining
    
copy_loop:
    vsetvli t3, t2, e32, m1 # Set vector length (t3 = actual elements)
    vle32.v v1, (t0)        # Load floats from my_data
    vse32.v v1, (t1)        # Store floats to shared memory
    
    # Update pointers and counter
    slli t4, t3, 2          # t4 = bytes copied (t3 * 4)
    add t0, t0, t4          # Advance source pointer
    add t1, t1, t4          # Advance destination pointer
    sub t2, t2, t3          # Decrease remaining count
    bnez t2, copy_loop      # Continue if more floats to copy
    
    # ====================
    # STEP 5: Release the lock (signal Python)
    # ====================
    # Ensure all writes complete before releasing lock
    fence w, w              # Write fence
    
    li t0, 1                # Lock value = 1
    sw t0, 0(s1)            # Write lock flag
    
    # Ensure lock write completes before reading it again
    fence w, r              # Write-to-read fence
    
    # ====================
    # OPTIONAL: Update your data here
    # ====================
    # This is where you'd do your computation to generate new data
    # For example: call your physics simulation, increment values, etc.
    # call my_physics_update
    
    # Loop forever (or add exit condition)
    j main_loop

# ====================
# ERROR HANDLER
# ====================
exit_error:
    li a7, 93               # syscall: exit
    li a0, 1                # exit code 1 (error)
    ecall


# ============================================================================
# NOTES FOR YOUR FRIENDS:
# ============================================================================
# 
# 1. SYNCHRONIZATION:
#    - The lock is a simple integer flag at the start of shared memory
#    - 0 means "Python is reading or ready for RISC-V to write"
#    - 1 means "RISC-V finished writing, Python should read"
#    - This is NOT a real mutex - it only works for exactly 2 processes
#
# 2. MEMORY FENCES:
#    - fence w, w: Ensures all writes complete before releasing lock
#    - fence w, r: Ensures lock write completes before reading it
#    - These prevent memory reordering bugs on modern CPUs
#
# 3. VECTOR INSTRUCTIONS:
#    - vsetvli: Set vector length (processes multiple elements at once)
#    - vle32.v: Vector load (32-bit elements)
#    - vse32.v: Vector store (32-bit elements)
#    - Much faster than copying one float at a time!
#
# 4. CUSTOMIZATION:
#    - Change N_FLOATS to match your data size
#    - Change MMAP_SIZE if you need more space (must match Python)
#    - Replace "my_data" with your actual data source
#    - Add your computation code where indicated
#
# 5. DEBUGGING:
#    - If Python hangs: RISC-V might have crashed before releasing lock
#    - If RISC-V hangs: Python might not be releasing lock (still == 1)
#    - Use debug prints (sys_write syscall) to trace execution
#
# ============================================================================
