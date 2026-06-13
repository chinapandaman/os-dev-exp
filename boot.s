/*
This file is the small assembly bridge between GRUB and the C kernel.

GRUB does not know that this file is a kernel just because it is named
boot.s. It recognizes a kernel by finding a Multiboot header: three 32-bit
numbers placed near the beginning of the final kernel binary.

.set creates assembler-time constants. These names do not become variables in
memory; they are just readable names for the numbers used below.
*/
.set ALIGN,    1<<0             /* ask GRUB to page-align loaded modules */
.set MEMINFO,  1<<1             /* ask GRUB to provide memory information */
.set FLAGS,    ALIGN | MEMINFO  /* combine the Multiboot options above */
.set MAGIC,    0x1BADB002       /* value GRUB searches for */
.set CHECKSUM, -(MAGIC + FLAGS) /* makes MAGIC + FLAGS + CHECKSUM equal 0 */

/*
This is the Multiboot header itself.

GRUB searches the first 8 KiB of the kernel file for MAGIC on a 4-byte
boundary. When it finds MAGIC, it reads the next two 32-bit values as FLAGS
and CHECKSUM. The checksum is a simple guard against finding the magic value
by accident: all three numbers must add up to 0.

The header has its own section so the linker script can keep it near the
front of the kernel file, where GRUB is able to find it.
*/
.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM

/*
Before C code can run, the CPU needs a stack.

GRUB jumps to our entry point with no stack set up for us. C functions use the
stack for return addresses, local variables, saved registers, and arguments,
so this file reserves a small stack in the kernel's .bss section.

.bss is for zero-initialized or uninitialized memory. The reserved stack space
exists when the kernel is loaded, but it does not need to take up bytes in the
kernel file on disk.

x86 stacks grow downward: pushing data subtracts from %esp. That is why the
first label is stack_bottom, the .skip reserves 16 KiB, and the second label is
stack_top. We will initialize %esp to stack_top before calling C.

The stack is aligned to 16 bytes because compiled C code may assume that
alignment when following the platform ABI.
*/
.section .bss
.align 16
stack_bottom:
.skip 16384 # reserve 16 KiB for the early kernel stack
stack_top:

/*
Code begins in the .text section.

The linker script names _start as the kernel entry point. After GRUB loads the
kernel, it jumps here. There is no caller to return to in the usual function
sense; once control reaches _start, the kernel owns the machine.
*/
.section .text
.global _start
.type _start, @function
_start:
	/*
	At this point GRUB has already done the earliest boot work:
	- the CPU is in 32-bit protected mode,
	- interrupts are disabled,
	- paging is disabled,
	- the machine state follows the Multiboot specification.

	What we do not have yet is an operating-system environment. There is no
	standard library, no printf, no heap, no files, no processes, and no
	automatic safety net. The kernel can only use the CPU, the hardware,
	and code that it provides for itself.
	*/

	/*
	Point the CPU's stack pointer at the top of the stack reserved above.
	Because the stack grows downward, the first push will use memory just
	below stack_top.
	*/
	mov $stack_top, %esp

	/*
	This minimal tutorial does not need more CPU setup before C runs.

	As the kernel grows, this spot is where very early setup often goes:
	loading your own GDT, enabling paging, preparing interrupt handling,
	initializing CPU features, or calling C++ runtime support before
	entering C++ code.
	*/

	/*
	Enter the C part of the kernel.

	kernel_main is expected to be defined in kernel.c. The call instruction
	pushes a return address onto the stack and jumps to kernel_main, just
	like an ordinary function call. The stack is still 16-byte aligned here,
	which keeps the call compatible with the ABI expected by the compiler.
	*/
	call kernel_main

	/*
	kernel_main normally should not return. If it does, there is nowhere
	useful to go, so stop the CPU in a quiet infinite loop.

	cli clears the interrupt-enable flag, so ordinary hardware interrupts
	will not wake the CPU. hlt then halts the CPU until something wakes it.
	If a non-maskable event does wake it, jmp 1b sends execution back to the
	local label "1" and halts again.
	*/
	cli
1:	hlt
	jmp 1b

/*
Tell the assembler how many bytes belong to the _start function.

"." means the current location. Subtracting _start gives the size of the code
from the _start label to this point. Debuggers and other tools can use this
symbol-size information.
*/
.size _start, . - _start
