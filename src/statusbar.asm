INCLUDE "defines.asm"
SECTION "init status bar", ROM0

InitStatusBar:: ;this should be called with the LCD off
    ;set up some shadow registers and actual registers
    ld a, LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_OBJON | LCDCF_BGON ;LCDC settings for the top of the screen
    ldh [hLCDC], a
    ld a, 7
    ldh [rWX], a
    xor a
    ldh [rWY], a ;put the window at the top left
    ldh [rLYC], a
    ld a, STATF_LYC
    ldh [rSTAT], a


    ;setup the LYC interrupt
    ld a, HIGH(StatusBarLYCTable)
    ldh [hLYCTableHigh], a
    ;unpack the tilemap
    ld de, $9C00 ;status bar goes at the top of the second tilemap
    ld hl, StatusBarTilemap
    ld b, SCRN_VX_B * 2 / 8 ;top 2 rows of the tilemap
    jp UnPB8 ;tail call


SECTION "status bar tilemap", ROM0
StatusBarTilemap:
    INCBIN "res/statusbar.maintileset.tilemap.pb8"

SECTION "status bar LYC table", ROM0, ALIGN[8] ;this table will e read byt the LYC handler
	;the format is like this:
	; 1: *NEXT* scaline number minus 1 for handling time
	; 2: value to write to LCDC on the *CURRENT* LYC scanline
	; this can repeat up to 128 times, but the table must start on a page boundary
	; at the end of the table, the next scanline number should be 0.
StatusBarLYCTable:
    db 10 - 1 ;at line 10 we disable sprites
    db 0 ; this is the argument for LYC 0. It isn't used rn

    db 16 - 1 ;at line 16 we turn off the window and start actually drawing the golf course using the bg
    db LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_BGON ;line 10 sprite disable

    db 0 ; line zero specifies the end of the table
    db LCDCF_ON | LCDCF_OBJON | LCDCF_BGON ;LCDC for main golf course







