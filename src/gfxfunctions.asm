INCLUDE "defines.asm"

SECTION "LCDMemsetSmallFromB", ROM0

; Writes a value to all bytes in an area of memory
; Works when the destination is in VRAM, even while the LCD is on
; @param hl Beginning of area to fill
; @param c Amount of bytes to write (0 causes 256 bytes to be written)
; @param a Value to write
; @return c 0
; @return hl Pointer to the byte after the last written one
; @return b Equal to a
; @return f Z set, C reset
LCDMemsetSmall::
	ld b, a
; Writes a value to all bytes in an area of memory
; Works when the destination is in VRAM, even while the LCD is on
; Protip: you may want to use `lb bc,` to set both B and C at the same time
; @param hl Beginning of area to fill
; @param c Amount of bytes to write (0 causes 256 bytes to be written)
; @param b Value to write
; @return c 0
; @return hl Pointer to the byte after the last written one
; @return b Equal to a
; @return f Z set, C reset
LCDMemsetSmallFromB::
	wait_vram
	ld a, b
	ld [hli], a
	dec c
	jr nz, LCDMemsetSmallFromB
	ret

SECTION "LCDMemset", ROM0

; Writes a value to all bytes in an area of memory
; Works when the destination is in VRAM, even while the LCD is on
; @param hl Beginning of area to fill
; @param bc Amount of bytes to write (0 causes 65536 bytes to be written)
; @param a Value to write
; @return bc 0
; @return hl Pointer to the byte after the last written one
; @return d Equal to parameter passed in a
; @return a 0
; @return f Z set, C reset
LCDMemset::
	ld d, a
; Writes a value to all bytes in an area of memory
; Works when the destination is in VRAM, even while the LCD is on
; @param hl Beginning of area to fill
; @param bc Amount of bytes to write (0 causes 65536 bytes to be written)
; @param d Value to write
; @return bc 0
; @return hl Pointer to the byte after the last written one
; @return a 0
; @return f Z set, C reset
LCDMemsetFromD::
	; Increment B if C is non-zero
	dec bc
	inc b
	inc c
.loop
	wait_vram
	ld a, d
	ld [hli], a
	dec c
	jr nz, .loop
	dec b
	jr nz, .loop
UncoditionalRet:: ;I use this to delay by calling a ret sometimes
	ret

SECTION "LCDMemcpySmall", ROM0

; Copies a block of memory somewhere else
; Works when the source or destination is in VRAM, even while the LCD is on
; @param de Pointer to beginning of block to copy
; @param hl Pointer to where to copy (bytes will be written from there onwards)
; @param c Amount of bytes to copy (0 causes 256 bytes to be copied)
; @return de Pointer to byte after last copied one
; @return hl Pointer to byte after last written one
; @return c 0
; @return a Last byte copied
; @return f Z set, C reset
LCDMemcpySmall::
	wait_vram
	ld a, [de]
	ld [hli], a
	inc de
	dec c
	jr nz, LCDMemcpySmall
	ret

SECTION "LCDMemcpy", ROM0

; Copies a block of memory somewhere else
; Works when the source or destination is in VRAM, even while the LCD is on
; @param de Pointer to beginning of block to copy
; @param hl Pointer to where to copy (bytes will be written from there onwards)
; @param bc Amount of bytes to copy (0 causes 65536 bytes to be copied)
; @return de Pointer to byte after last copied one
; @return hl Pointer to byte after last written one
; @return bc 0
; @return a 0
; @return f Z set, C reset
LCDMemcpy::
	; Increment B if C is non-zero
	dec bc
	inc b
	inc c
.loop
	wait_vram
	ld a, [de]
	ld [hli], a
	inc de
	dec c
	jr nz, .loop
	dec b
	jr nz, .loop
	ret

SECTION "render sprite 12.4", ROM0
;Chack if a sprite is no the screen, and render it if it is.
/* Params:
HL: pointer to 12.4 Y position, followed by 12.4 Y position
B: Y offset from the center of the sprite to the top edge
C: X offset from the center of the sprite to the left edge
DE: pointer to the shadow OAM entry where this sprite can go

Returns:
HL: Points to the tile number byte in shadow OAM to be written by the caller
BC: is preserved
Clobbers A, DE
*/
RenderSprite124::
    push de
        ld a, [hl+] ;low byte
        ld e, a
        ld a, [hl+] ;high byte
        cp 16 ;make sure it's within the 256 px tilemap range
        jr nc, .hide ;and hide it if it's not
        xor e
        and $0f
        xor e ;masked merge
        swap a 
        add b ;add the edge offset
        ld e, a ;store it in e until we're ready to write it
        ;subtract the camera position
        ldh a, [hSCY]
        cpl ; invert it. The inc a is bakes into the next add
        add 1 + OAM_Y_OFS ;convert to OAM position
        add e
        cp STATUS_BAR_HEIGHT - 8 + OAM_Y_OFS;if the sprite is fully hidden by the status bar, don't draw it
        jr c, .hide
        ld e, a

        ;now for the X coordinate
        ;do the whole fetch and masked merge thing again
        ld a, [hl+] ;low byte
        ld d, a
        ld a, [hl+] ;high byte
        cp 16 ;make sure it's within the 256 px tilemap range
        jr nc, .hide ;and hide it if it's not
        xor d
        and $0f
        xor d ;masked merge
        swap a
        ;subtract the camera position
        ld hl, hSCX
        sub [hl]
        add OAM_X_OFS  ;convert to OAM position
        add c ;add the edge offset


        ;now we can clobber hl and start writing these
    pop hl ;the entry in Shadow OAM
    ld [hl], e ;y coordinate first
    inc l ;shadow OAM is aligned so this is fine
    ld [hl+], a ;X coordinate   
    ret



.hide
    pop hl;zero the Y coordinate in OAM to hide it
    xor a
    ld [hl+], a
    inc l ;the caller expects this to point to the tile index byte, so increment it anyways
    ret
