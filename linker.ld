/*
This linker script tells the linker how to combine the object files produced
from boot.s and kernel.c into one ELF kernel image.

Object files already contain named input sections such as .text, .rodata,
.data, .bss, and the custom .multiboot section from boot.s. The linker script
chooses where those input sections land in the final executable and what
address each symbol will have when the kernel is loaded.
*/

/*
Set the ELF entry point to the _start symbol defined in boot.s.

GRUB reads this entry address from the ELF header after loading the kernel and
jumps there. This does not move _start by itself; it only says which already-
placed symbol is the first instruction to execute.
*/
ENTRY(_start)

/*
SECTIONS is the memory map for the output file. Inside it, "." is the linker
location counter: the address where the next output byte will be placed.
Assigning to "." moves that address forward and creates gaps/padding as needed.
*/
SECTIONS
{
	/*
	Start the kernel at physical address 2 MiB.

	Older tutorials often used 1 MiB because that area was usually available
	on BIOS machines. OSDev's Bare Bones tutorial now chooses 2 MiB as a more
	cautious fixed load address on modern firmware.

	At this point the tutorial has paging disabled, so the addresses the
	linker assigns are the physical addresses GRUB should load and jump to.
	*/
	. = 2M;

	/*
	Executable code section.

	BLOCK(4K) advances the location counter to a 4 KiB boundary before this
	output section starts, and ALIGN(4K) records a 4 KiB alignment for the
	section in the output ELF. Page alignment is useful once the kernel begins
	setting up page tables.

	*(.multiboot) copies every input section named .multiboot into this output
	section first. The Multiboot v1 header must be near the beginning of the
	kernel file for GRUB to recognize it, so it appears before normal code.

	*(.text) then copies all ordinary executable code, including _start from
	boot.s and the compiled functions from kernel.c.
	*/
	.text BLOCK(4K) : ALIGN(4K)
	{
		*(.multiboot)
		*(.text)
	}

	/*
	Read-only data.

	String literals, const objects, jump tables, and similar compiler-emitted
	values live here. Keeping them separate from writable data lets a future
	kernel map this section read-only.
	*/
	.rodata BLOCK(4K) : ALIGN(4K)
	{
		*(.rodata)
	}

	/*
	Initialized writable data.

	Global/static variables with explicit non-zero initial values are stored in
	the kernel file so GRUB can copy those bytes into memory exactly as linked.
	*/
	.data BLOCK(4K) : ALIGN(4K)
	{
		*(.data)
	}

	/*
	Uninitialized writable data.

	.bss is different from .data: it reserves memory but does not need to store
	all-zero bytes in the kernel file. For an ELF kernel, GRUB allocates and
	clears this memory when loading the segment.

	*(COMMON) catches old-style tentative global definitions that some C
	compilers may emit as "common" symbols instead of putting them directly in
	.bss. The stack reserved in boot.s is also in .bss.
	*/
	.bss BLOCK(4K) : ALIGN(4K)
	{
		*(COMMON)
		*(.bss)
	}

	/*
	If the compiler or assembler starts producing additional sections, the
	linker may place them using its orphan-section rules. As the kernel grows,
	add important sections here explicitly so their placement and permissions
	are intentional.
	*/
}
