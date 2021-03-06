
INCLUDE "defines.asm"

SECTION "Rst $00", ROM0[$00]

NULL::
	; This traps jumps to $0000, which is a common "default" pointer
	; $FFFF is another one, but reads rIE as the instruction byte
	; Thus, we put two `nop`s that may serve as operands, before soft-crashing
	; The operand will always be 0, so even jumps will work fine. Nice!
	nop
	nop
	rst Crash

SECTION "Rst $08", ROM0[$08]

; Waits for the next VBlank beginning
; Requires the VBlank handler to be able to trigger, otherwise will loop infinitely
; This means IME should be set, the VBlank interrupt should be selected in IE,
; and the LCD should be turned on.
; WARNING: Be careful if calling this with IME reset (`di`), if this was compiled
; with the `-h` flag, then a hardware bug is very likely to cause this routine to
; go horribly wrong.
; Note: the VBlank handler recognizes being called from this function (through `hVBlankFlag`),
; and does not try to save registers if so. To be safe, consider all registers to be destroyed.
; @destroy Possibly every register. The VBlank handler stops preserving anything when executed from this function
WaitVBlank::
	ld a, 1
	ldh [hVBlankFlag], a
.wait
	halt
	jr .wait

SECTION "Rst $10", ROM0[$10 - 1]

MemsetLoop:
	ld a, d

	assert @ == $10
; You probably don't want to use this for writing to VRAM while the LCD is on. See LCDMemset.
Memset::
	ld [hli], a
	ld d, a
	dec bc
	ld a, b
	or c
	jr nz, MemsetLoop
	ret

SECTION "Rst $18", ROM0[$18]

MemcpySmall::
	ld a, [de]
	ld [hli], a
	inc de
	dec c
	jr nz, MemcpySmall
	ret

SECTION "Rst $20", ROM0[$20]

MemsetSmall::
	ld [hli], a
	dec c
	jr nz, MemsetSmall
	ret

SECTION "Rst $28", ROM0[$28 - 3]

; Dereferences `hl` and jumps there
; All other registers are passed to the called code intact, except Z is reset
; Soft-crashes if the jump target is in RAM
; @param hl Pointer to an address to jump to
JumpToPtr::
	ld a, [hli]
	ld h, [hl]
	ld l, a

	assert @ == $28
; Jump to some address
; All registers are passed to the called code intact, except Z is reset
; (`jp CallHL` is equivalent to `jp hl`, but with the extra error checking on top)
; Soft-crashes if attempting to jump to RAM
; @param hl The address of the code to jump to
CallHL::
	bit 7, h
	error nz
	jp hl

SECTION "Rst $30", ROM0[$30]

; Jumps to some address
; All registers are passed to the target code intact, except Z is reset
; (`jp CallDE` would be equivalent to `jp de` if that instruction existed)
; Soft-crashes if attempting to jump to RAM
; @param de The address of the code to jump to
CallDE::
	bit 7, d
	push de
	ret z ; No jumping to RAM, boy!
	rst Crash

SECTION "Rst $38", ROM0[$38]

; Perform a soft-crash. Prints debug info on-screen
Crash::
	di ; Doing this as soon as possible to avoid interrupts messing up
	jp HandleCrash

SECTION "Handlers", ROM0[$40]

; VBlank handler
	push af
	ldh a, [hLCDC]
	ldh [rLCDC], a
	jp VBlankHandler
	ds $48 - @

; STAT handler 
	push af 
	push hl
	jp STATHandler
	ds $50 - @

; Timer handler
	rst $38
	ds $58 - @

; Serial handler
	rst $38
	ds $60 - @

; Joypad handler (useless)
	rst $38

SECTION "STAT Handler", ROM0
STATHandler: ;this handler processes a table full of LYC values and things to write to LCDC.
	;the format is like this:
	; 1: *NEXT* scaline number minus 1 for handling time
	; 2: value to write to LCDC on the *CURRENT* LYC scanline
	; this can repeat up to 128 times, but the table must start on a page boundary
	; at the end of the table, the next scanline number should be 1 for the music update on the next frame
LYC_TABLE_END equ 1
EXPORT LYC_TABLE_END

	;to avoid breaking VRAM writes, the LYC handler must take between 87 and 109 cycles, 
	;and should only mess with PPU registers after cycle 87 (which is guaranteed to me mode 0 or mode 2)
	;we've already used 12 cycles
	ldh a, [rLYC] ;check if LYC=1, because I'll use that for music drivers and resetting the LYC table index
	dec a
	jr z, STATHandlerLYOne ;now we've used 18 cycles
	;we have this table full of values to write to rLCDC and line numbers for the next interrupt
	ldh a, [hLYCTableHigh]
	ld h, a
	ldh a, [hLYCTableLow]
	ld l, a ;so now we've got the pointer to the table
	;we've used 26 cycles now
	ld a, [hl+] ;this is the line number when the next LYC should fire
	ldh [rLYC], a
	ld a, [hl+] ;and this is the value we should write to rLCDC once the PPU reaches the end of the line
	ld h, a ;we're done with h now, so we may as well store the value here instead of pushing bc or de.
	;we've used 34 cycles now
	ld a, l ;now we store the LYC table pointer 
	ldh [hLYCTableLow], a
	ld a, h ;get the pop done ahead of time
	pop hl
	;and that's 42 cycles. now we have to sleep for 43 more cycles, then do the write and get out of there. 
	;calling a ret takes 10 cycles
	call UncoditionalRet
	call UncoditionalRet
	call UncoditionalRet
	call UncoditionalRet
	;now sleep for 3 cycles
	nop
	nop
	nop 
	;do the write. The actual write happends on the third cycle, which will be the 88th cycle when we're guaranteed to be in Hblank.
	ldh [rLCDC], a
	;and finish up
	pop af
	reti

STATHandlerLYOne: ;this special case will handle music updates and resetting the LYC table
	xor a ;reset the LYC table pointer
	ldh [hLYCTableLow], a
	ld l, a
	ldh a, [hLYCTableHigh]
	ld h, a ;now hl points to the start of the table
	ld a, [hl+]
	ldh [rLYC], a ;prepare the next LYC
	inc l ;skip the argument for LYC=0
	ld a, l
	ldh [hLYCTableLow], a

	ei

	;now update music
	
	;busy-loop for the start of Hblank so we can return safely without messing up any VRAM accesses
	ld   hl, rSTAT
    ; Wait until Mode is -NOT- 0 or 1
.waitNotBlank
    bit  1, [hl]
    jr   z, .waitNotBlank
    ; Wait until Mode 0 or 1 -BEGINS- (but we know that Mode 0 is what will begin)
.waitBlank
    bit  1, [hl]
    jr   nz, .waitBlank

	pop hl
	pop af
	
	ret


SECTION "STAT HRAM", HRAM
hLYCTableLow: ;this is overwritten after every LYC as we advance through this table
	ds 1
hLYCTableHigh:: ;the high byte is not written, so we assume that the whole table is on one page, but we can use this to point the handler to multiple tables.
	ds 1


SECTION "VBlank handler", ROM0

VBlankHandler:
	ldh a, [hSCY]
	ldh [rSCY], a
	ldh a, [hSCX]
	ldh [rSCX], a
	ldh a, [hBGP]
	ldh [rBGP], a
	ldh a, [hOBP0]
	ldh [rOBP0], a
	ldh a, [hOBP1]
	ldh [rOBP1], a

	; OAM DMA can occur late in the handler, because it will still work even
	; outside of VBlank. Sprites just will not appear on the scanline(s)
	; during which it's running.
	ldh a, [hOAMHigh]
	and a
	jr z, .noOAMTransfer
	call hOAMDMA
	xor a
	ldh [hOAMHigh], a
.noOAMTransfer

	; Put all operations that cannot be interrupted above this line
	; For example, OAM DMA (can't jump to ROM in the middle of it),
	; VRAM accesses (can't screw up timing), etc
	ei

	ldh a, [hVBlankFlag]
	and a
	jr z, .lagFrame
	xor a
	ldh [hVBlankFlag], a



	pop af ; Pop off return address as well to exit infinite loop
.lagFrame
	pop af
	ret



SECTION "VBlank HRAM", HRAM

; DO NOT TOUCH THIS
; When this flag is set, the VBlank handler will assume the caller is `WaitVBlank`,
; and attempt to exit it. You don't want that to happen outside of that function.
hVBlankFlag:: db

; High byte of the address of the OAM buffer to use.
; When this is non-zero, the VBlank handler will write that value to rDMA, and
; reset it.
hOAMHigh:: db

; Shadow registers for a bunch of hardware regs.
; Writing to these causes them to take effect more or less immediately, so these
; are copied to the hardware regs by the VBlank handler, taking effect between frames.
; They also come in handy for "resetting" them if modifying them mid-frame for raster FX.
hLCDC:: db
hSCY:: db
hSCX:: db
hBGP:: db
hOBP0:: db
hOBP1:: db


; If this is 0, pressing SsAB at the same time will not reset the game
hCanSoftReset:: db
