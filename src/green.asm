INCLUDE "defines.asm"

SECTION "Toggle Green", ROM0
ToggleGreen:: ; Called when the user presses select during the main game
    call ClearOAM
    
    ldh a, [hGameState]
    xor GREEN_FLAG ; toggle the green bit
    ldh [hGameState], a

    ; Now set the appropriate LYC table
    and GREEN_FLAG ; zero all bits except the green bit
    jr z, .switchToMainScreen

.switchToGreen
    xor a
    ldh [hAimCursorDirection], a

    ld a, HIGH(GreenLYCTable)
    ldh [hLYCTableHigh], a
    ret

.switchToMainScreen
    ld a, HIGH(StatusBarLYCTable)
	ldh [hLYCTableHigh], a
    ret



SECTION "render sprite 12.4 On Green", ROM0
;Check if a sprite is on the green, and render it if it is.
/* Params:
HL: pointer to 12.4 Y position, followed by 12.4 X position
B: Y offset from the center of the sprite to the top edge
C: X offset from the center of the sprite to the left edge
DE: pointer to the shadow OAM entry where this sprite can go

Returns:
HL: Points to the tile number byte in shadow OAM to be written by the caller
BC: is preserved
Clobbers A, DE
*/
RenderSprite124OnGreen::
    push bc
        push de
            ldh a, [hGreenCoordY]
            ld c, a
            ld a, [hl+]
            sub c
            ld c, a
            ldh a, [hGreenCoordY + 1]
            ld b, a
            ld a, [hl+]
            sbc b;for the Y coordinate, the difference must be 16 whole pixels or less, 
            ;so in 12.4, the difference must be 256 or less, which means the high byte needs to be 0
            jr nz, .hide

            ld b, a;store the difference in BC
        
            ;now do the same for the X
            ldh a, [hGreenCoordX]
            ld e, a
            ld a, [hl+]
            sub e
            ld e, a
            ldh a, [hGreenCoordX + 1]
            ld d, a
            ld a, [hl+]
            sbc d ;for the X coordinate, the difference must be 20 whole pixels or less, so in 12.4 thats $140 or less
            ld d, a
            jr z, .draw
            dec a
            jr nz, .hide
            ld a, e
            cp $40 ;if the difference is greater than $140, then the ball is off the screen
            jr nc, .hide

        .draw
        ;if all those checks passed, then we can draw the ball. The 12.4 Y coordinate is stored in BC, and the 12.4 X coordinate is stored in DE
        pop hl

        ld a, c
        rr b
        rra 
    pop bc ;we're done with bc now, just in time to pop the offsets
    add b
    add OAM_Y_OFS + STATUS_BAR_HEIGHT ; relative to the bottom of the status bar
    ld [hl+], a ;write the Y coordinate to the OAM

    ld a, e
    rr d
    rra
    add c
    add OAM_X_OFS
    ld [hl+], a ;write the X coordinate to the OAM
    ret

        .hide
            ;hide the ball by zeroing its Y coordinate
            pop hl
        pop bc
    ld [hl], 0
    inc l
    inc l ;the caller still needs hl to point to the tile number
    ret





SECTION "Green LYC table", ROM0, ALIGN[8] ;this table will be read by the LYC handler
;the format is like this:
; 1: *NEXT* scaline number minus 1 for handling time
; 2: value to write to LCDC on the *CURRENT* LYC scanline
; this can repeat up to 128 times, but the table must start on a page boundary
; at the end of the table, the next scanline number should be 1.
GreenLYCTable:
db 8 - 1 ;at line 8 we disable sprites
db 0 ; this is the argument for LYC 1. It isn't used rn

db STATUS_BAR_HEIGHT - 1 ;at line 16 we re-enable sprites for the green, which still uses the window
db LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_BGON ;line 10 sprite disable

db LYC_TABLE_END ;finish off the table
db LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_OBJON | LCDCF_BGON ;LCDC for main golf course

SECTION "Green HRAM", HRAM

; this is the 12.4 tilemap-relative coordinates for the upper-left corner of the green
hGreenCoordY::
    dw
hGreenCoordX::
    dw

