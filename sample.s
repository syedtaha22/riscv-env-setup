# ========================================================================
#       Riscv Assembly Code for Vector Addition Using Vector extension
#
# void vector_add(const float* a, const float* b, float* result, int n) {
#     for (int i = 0; i < n; i++) {
#         result[i] = a[i] + b[i];
#     }
# }
# ========================================================================

# Neccessary For VEER-ISS/whisper
#define STDOUT 0xd0580000

.section .text
.global _start  # _start is mandatory for the linker to know where to start execution, Basically like main in C/C++
_start:

    addi a0, x0, 20              # Number of elements
    li x1, 0xd0580000            # Load address for output
    la a1, a                     # Load address of first vector
    la a2, b                     # Load address of second vector
    la a3, result                # Load address for result

vvaddfloat:
    vsetvli t0, a0, e32, ta, ma  # Set vector length based on 32-bit floats

    sub a0, a0, t0               # Decrement number of elements
    slli t0, t0, 2               # Multiply number of elements by 4 bytes, for byte offset

    vle32.v v0, (a1)             # Load first vector
    add a1, a1, t0               # Increment pointer for first vector

    vle32.v v1, (a2)             # Load second vector
    add a2, a2, t0               # Increment pointer for second vector


    vfadd.vv v2, v0, v1          # Add vectors
    vse32.v v2, (a3)             # Store result
    add a3, a3, t0               # Increment pointer for result
    bnez a0, vvaddfloat          # Loop back if not done



# Necessary for VeeR-ISS/whisper to stop execution
_finish:
    li x3, 0xd0580000
    addi x5, x0, 0xff
    sb x5, 0(x3)
    beq x0, x0, _finish
.rept 100
    nop
.endr

.data
a:      
.float 00.0, 01.0, 02.0, 03.0, 04.0, 05.0, 06.0, 07.0, 08.0, 09.0
.float 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0

b:      
.float 20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0, 29.0
.float 30.0, 31.0, 32.0, 33.0, 34.0, 35.0, 36.0, 37.0, 38.0, 39.0

result: .space 80 # Allocate space for 20 floats, i.e 4x20 bytes