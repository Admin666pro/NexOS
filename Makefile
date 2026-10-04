NASM      = nasm
WCC       = wcc
WLINK     = wlink

NASM_OBJ  = -f obj \
    -I kernel -I drivers -I gfx -I fs -I gui \
    -I install -I apps -I c -I data -I build

WCCFLAGS  = -ms -0 -bt=none -zq -zcm -w4
BUILD     = build

all: $(BUILD)/mbr.bin $(BUILD)/hdboot.bin $(BUILD)/kernel.bin

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/mbr.bin: boot/mbr.asm | $(BUILD)
	$(NASM) -f bin -o $@ $<

$(BUILD)/hdboot.bin: boot/hdboot.asm | $(BUILD)
	$(NASM) -f bin -o $@ $<

$(BUILD)/kernel.obj: kernel/kernel.asm | $(BUILD)
	$(NASM) $(NASM_OBJ) -o $@ $<

$(BUILD)/%.obj: c/%.c | $(BUILD)
	$(WCC) $(WCCFLAGS) -fo $@ $<

$(BUILD)/kernel.bin: $(BUILD)/kernel.obj $(BUILD)/kmain.obj $(BUILD)/crt.obj
	cd $(BUILD) && $(WLINK) system bin name kernel.bin &
	    file kernel.obj,kmain.obj,crt.obj

clean:
	rm -rf $(BUILD)