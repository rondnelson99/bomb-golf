INCLUDE "defines.asm"

SECTION "Green Main Loop", ROM0

SwitchToGreen:: ; jump here to start viewing the green. Takes over the main loop.
    ; since the green has a different tilemap, we need to switch the LYC table
    ld a, HIGH(GreenLYCTable)
    ldh [hLYCTableHigh], a

    jr GreenMainLoopNoSwitch




GreenMainLoop:
    ;first check if we need to switch to the main view. This is triggered by the user pressing select.
	ldh a, [hPressedKeys]
	bit PADB_SELECT, a
	jp nz, SwitchToMainScreen
GreenMainLoopNoSwitch:






    ld a, HIGH(wShadowOAM)
	ldh [hOAMHigh], a
.end
	rst WaitVBlank
	jr GreenMainLoop

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

; this is the tilemap-relative coordinates for the upper-left corner of the green
hGreenCoordY::
    db
hGreenCoordX::
    db

