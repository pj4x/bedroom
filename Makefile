RPI_VERSION ?= 4

# Bare-metal AArch64 toolchain installed via Homebrew
ARMGNU ?= aarch64-elf

COPS = -DRPI_VERSION=$(RPI_VERSION) \
       -Wall -Wextra -O2 \
       -ffreestanding -fno-stack-protector \
       -fno-pic -mgeneral-regs-only \
       -Iinclude

ASMOPS = -Iinclude

BUILD_DIR = build
SRC_DIR = src

BOOTMNT = /Volumes/bootfs

.PHONY: all clean

all: kernel8.img

clean:
	rm -rf $(BUILD_DIR) kernel8.img

$(BUILD_DIR)/%_c.o: $(SRC_DIR)/%.c
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(COPS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(ASMOPS) -MMD -MP -c $< -o $@

C_FILES = $(wildcard $(SRC_DIR)/*.c)
ASM_FILES = $(wildcard $(SRC_DIR)/*.S)

OBJ_FILES = $(C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%_c.o)
OBJ_FILES += $(ASM_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%_s.o)

DEP_FILES = $(OBJ_FILES:%.o=%.d)
-include $(DEP_FILES)

kernel8.img: $(SRC_DIR)/linker.ld $(OBJ_FILES)
	@echo "Building for Raspberry Pi $(RPI_VERSION)"
	$(ARMGNU)-ld -T $(SRC_DIR)/linker.ld \
	    -o $(BUILD_DIR)/kernel8.elf $(OBJ_FILES)
	$(ARMGNU)-objcopy $(BUILD_DIR)/kernel8.elf \
	    -O binary kernel8.img
	cp kernel8.img $(BOOTMNT)/
	cp config.txt $(BOOTMNT)/
	sync
	@echo ""
	@echo "Build complete: kernel8.img"
	@echo "ELF file: $(BUILD_DIR)/kernel8.elf"

armstub/build/armstub_s.o: armstub/src/armstub.S
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

armstub: armstub/build/armstub_s.o
	$(ARMGNU)-ld --section-start=.text=0 -o armstub/build/armstub.elf armstub/build/armstub_s.o
	$(ARMGNU)-objcopy armstub/build/armstub.elf -O binary armstub-new.bin
	cp armstub-new.bin $(BOOTMNT)/
	sync
