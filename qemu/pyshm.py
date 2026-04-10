# ============================================================================
# ACKNOWLEDGEMENTS
# ============================================================================
# This file was written and provided by Hamza Ahmed (Github: Witherthrottle)
# ============================================================================


import mmap
import os
import struct
import subprocess
import time

# ============================================================================
# SHARED MEMORY COMMUNICATION: PYTHON SIDE
# ============================================================================
# This code demonstrates how to receive data from a RISC-V program using
# shared memory with a simple lock-based synchronization mechanism.
# 
# MEMORY LAYOUT:
# [0-3]:     Lock flag (4 bytes, int32)
#            0 = Python's turn to read
#            1 = RISC-V's turn to write
# [4-end]:   Data payload (floats or whatever you need)
# ============================================================================

# Configuration
FILENAME = "build/shared.mem"
N_FLOATS = 100              # Number of floats to transfer per iteration
DATA_SIZE = N_FLOATS * 4    # 4 bytes per float
FILESIZE = 4096             # Total mmap size (must match RISC-V)

def initialize_shared_memory():
    """Create and initialize the shared memory file."""
    # Create file filled with zeros
    with open(FILENAME, "wb") as f:
        f.write(b'\x00' * FILESIZE)
    
    # Open for reading/writing and memory map it
    f = open(FILENAME, "r+b")
    mem = mmap.mmap(f.fileno(), FILESIZE, access=mmap.ACCESS_WRITE)
    
    # Initialize lock to 0 (Python starts by waiting)
    mem[0:4] = struct.pack('<i', 0)
    
    return f, mem

def start_riscv_process():
    """Launch the RISC-V executable using QEMU. """
    print("[Python] Starting RISC-V process...")
    process = subprocess.Popen(
        ["qemu-riscv32", "-cpu", "rv32,v=true", "./build/exe/rvshm.exe"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    return process

def wait_for_data(mem, process, timeout=1.0):
    """
    Wait for RISC-V to signal data is ready.
    
    Returns True if data is ready, False if timeout or process died.
    """
    start = time.time()
    
    while True:
        # Check if lock flag is 1 (RISC-V finished writing)
        flag = struct.unpack('<i', mem[0:4])[0]
        
        if flag == 1:
            return True
        
        # Check if RISC-V process died
        if process.poll() is not None:
            print(f"[Error] RISC-V process died with code {process.returncode}")
            stderr = process.stderr.read().decode('utf-8', errors='replace')
            if stderr:
                print(f"[Error] stderr: {stderr}")
            return False
        
        # Check timeout
        if time.time() - start > timeout:
            print("[Warning] Timeout waiting for RISC-V")
            return False
        
        time.sleep(0.001)  # Small sleep to avoid busy-waiting

def read_data(mem):
    """
    Read data from shared memory.
    
    Returns a list of floats.
    """
    # Read floats from offset 4 onwards
    raw_data = mem[4:4+DATA_SIZE]
    values = struct.unpack(f'<{N_FLOATS}f', raw_data)
    return list(values)

def release_lock(mem):
    """
    Signal to RISC-V that Python is done reading.
    Sets lock flag to 0.
    """
    mem[0:4] = struct.pack('<i', 0)

def main():
    """Main communication loop."""
    # Initialize
    f, mem = initialize_shared_memory()
    process = start_riscv_process()
    
    iteration = 0
    
    try:
        while True:
            # 1. WAIT for RISC-V to write data
            if not wait_for_data(mem, process):
                break
            
            # 2. READ the data
            data = read_data(mem)
            
            # 3. PROCESS your data here
            print(f"[Python] Iteration {iteration}: Received {len(data)} floats")
            print(f"[Python] First 5 values: {data[:5]}")
            
            # 4. RELEASE the lock (tell RISC-V we're done)
            release_lock(mem)
            
            iteration += 1
            
            # Optional: Add exit condition
            if iteration >= 100:  # Stop after 100 iterations
                break
    
    except KeyboardInterrupt:
        print("\n[Python] Interrupted by user")
    
    finally:
        # Cleanup
        print("[Python] Cleaning up...")
        mem.close()
        f.close()
        process.terminate()
        process.wait(timeout=2)
        if process.poll() is None:
            process.kill()
        print("[Python] Done")

if __name__ == "__main__":
    main()
