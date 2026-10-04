NASM      = nasm
WCC       = owcc
WLINK     = wlink

NASM_OBJ  = -f obj \
    -I kernel -I drivers -I gfx -I fs -I gui \
    -I install -I apps -I c -I data -I build

# owcc 的 16 位选项
WCCFLAGS = -b dos -mcmodel=l -mtune=i086 -fno-stack-check -Wall -Wc,-zt164 -c
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
	$(WCC) $(WCCFLAGS) -o $@ $<

$(BUILD)/kernel.bin: $(BUILD)/kernel.obj $(BUILD)/kmain.obj $(BUILD)/crt.obj
	cd $(BUILD) && $(WLINK) system dos name kernel.bin \
	    option stack=4k \
	    option start=main_ \
	    file kernel.obj,kmain.obj,crt.obj \
	    library clibl.lib

clean:
	rm -rf $(BUILD)