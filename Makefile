NASM      = nasm
NASM_OBJ  = -f obj -I . -I kernel -I drivers -I gfx -I fs -I gui -I install -I apps

WCC       = wcc
WCCFLAGS  = -ms -0 -bt=none -zq -zcm -w4

WLINK     = wlink

BUILD     = build

ASM_SRCS  = kernel/kernel.asm c/c_api.asm
C_SRCS    = c/kmain.c c/crt.c

ASM_OBJS  = $(BUILD)/kernel.obj $(BUILD)/c_api.obj
C_OBJS    = $(BUILD)/kmain.obj  $(BUILD)/crt.obj

all: $(BUILD)/mbr.bin $(BUILD)/hdboot.bin $(BUILD)/kernel.bin

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/mbr.bin: boot/mbr.asm | $(BUILD)
	$(NASM) -f bin -o $@ $<

$(BUILD)/hdboot.bin: boot/hdboot.asm | $(BUILD)
	$(NASM) -f bin -o $@ $<

$(BUILD)/kernel.obj: kernel/kernel.asm | $(BUILD)
	cd $(BUILD) && $(NASM) $(NASM_OBJ) -o kernel.obj ../kernel/kernel.asm

$(BUILD)/c_api.obj: c/c_api.asm | $(BUILD)
	$(NASM) $(NASM_OBJ) -o $@ $<

$(BUILD)/%.obj: c/%.c | $(BUILD)
	$(WCC) $(WCCFLAGS) -fo=$@ $<

$(BUILD)/kernel.bin: $(ASM_OBJS) $(C_OBJS)
	cd $(BUILD) && $(WLINK) system bin name kernel.bin &
	    file kernel.obj,c_api.obj,kmain.obj,crt.obj &
	    option map=kernel.map

clean:
	rm -rf $(BUILD)