# Compiler and flags for Zig (using native build-obj)
ZIG            = zig build-obj
TARGET_FLAGS   = -target x86-freestanding -mcpu=i386
COMMON_FLAGS   = -fPIC
INCLUDE_FLAGS  = -I.
ZIG_EXTRA_FLAGS= -fno-stack-check -Drelease-fast

# Linker and flags
LD       = x86_64-elf-ld
LD_FLAGS = -m elf_i386 -T linker.ld -o kernel.bin

# GRUB rescue tool
GRUB_MKRESCUE = i686-elf-grub-mkrescue

# sources
ZIG_SRCS := $(wildcard *.zig)
ASM_SRCS := $(wildcard *.s)

clean:
	rm -rf build
	rm -f *.o
	rm -f *.bin
	rm -f *.iso

%.o: %.s
	$(ZIG) $(TARGET_FLAGS) $< $(COMMON_FLAGS)
%.o: %.zig
	$(ZIG) $(TARGET_FLAGS) $(INCLUDE_FLAGS) $< $(ZIG_EXTRA_FLAGS) $(COMMON_FLAGS)

ziggy: clean $(ASM_SRCS:.s=.o) $(ZIG_SRCS:.zig=.o)
	# Link the kernel binary
	$(LD) $(LD_FLAGS) multiboot_header.o boot.o main.o console.o string.o asm_lib.o

	# Prepare ISO structure and copy files
	mkdir -p build/isofiles/boot/grub/
	cp boot/grub.cfg build/isofiles/boot/grub/grub.cfg
	cp kernel.bin build/isofiles/boot/

	# Create bootable ISO image
	$(GRUB_MKRESCUE) -o ziggy.iso build/isofiles

qemu: ziggy
	qemu-system-i386 -cdrom ziggy.iso -vga std -no-reboot -nographic


etch: ziggy
	@echo "Checking if /dev/disk4 is external..."
	@if (diskutil info /dev/disk4 | grep -q "Device Location: *External") && (diskutil info /dev/disk4 | grep -q "Protocol: *USB"); then \
		echo "/dev/disk4 is confirmed external."; \
		echo "Unmounting /dev/disk4..."; \
		diskutil unmountDisk /dev/disk4; \
		echo "Etching ziggy.iso to /dev/rdisk4..."; \
		sudo dd if=ziggy.iso of=/dev/rdisk4 bs=4m status=progress && sync; \
		echo "Ejecting /dev/disk4..."; \
		diskutil eject /dev/disk4; \
	else \
		echo "Error: /dev/disk4 is not external. Aborting."; \
		exit 1; \
	fi