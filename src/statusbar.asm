INCLUDE "defines.asm"

STATUS_BAR_HEIGHT equ 16
EXPORT STATUS_BAR_HEIGHT

SECTION "init status bar", ROM0

InitStatusBar:: ;this should be called with the LCD off
    ;set up some shadow registers and actual registers
    ld a, LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_OBJON | LCDCF_BGON ;LCDC settings for the top of the screen
    ldh [hLCDC], a
    ld a, 7
    ldh [rWX], a
    xor a
    ldh [rWY], a ;put the window at the top left
    assert LYC_TABLE_END == 1
    inc a ;ld a, LYC_TABLE_END
    ldh [rLYC], a
    ld a, STATF_LYC
    ldh [rSTAT], a
    ld a, IEF_LCDC | IEF_VBLANK
    ldh [rIE], a
    ;setup the LYC interrupt
    ld a, HIGH(StatusBarLYCTable)
    ldh [hLYCTableHigh], a


    ;unpack the tilemap
    ld de, $9C00 ;status bar goes at the top of the second tilemap
    ld hl, StatusBarTilemap
    ld b, SCRN_VX_B * 2 / 8 ;top 2 rows of the tilemap
    jp UnPB8 ;tail call

SECTION "status bar variables", WRAM0
wPowerMeterLevel:: ; stores how much power is stored in the power meter as a count of pixels from the right end (zero power)
    db

METER_ARROW_Y equ 4 ;the arrow starts on line 4 of the screen
ARROW_CENTER_OFFSET equ 3 ;add this to the leftmost pixel of the tile to get the center
METER_SIZE equ 79 ;distance from the left edge of the screen to the end of the meter
export METER_SIZE ;used in stroke.asm
METER_TARGET equ 23 ;23 power puts the arrow right on the target
export METER_TARGET ;also in stroke.asm


SECTION "update power meter", ROM0
UpdatePowerMeter:: ;updates the power meter arrow in shadow OAM from the level stored in wPowerMeterLevel
    ld hl, OBJ_METER ;pointer to the entry in Shadow OAM
    ld a, 16 + METER_ARROW_Y
    ld [hl+], a ;write the Y coordinate

    ld a, [wPowerMeterLevel] ;grab the power level
    cpl ;invert it. Instead an `inc a`, the extra 1 will be baked into the next step
    add 1 + 8 - ARROW_CENTER_OFFSET + METER_SIZE ;get an OAM X position. The 8 is the OAM offset.
    ld [hl+], a ;write the X coordinate

    ld a, SPRITE_METER ;this is the sprite number
    ld [hl+], a ;write it too

    ld [hl], 0 ;this doesn't require any special flags
    
    ret








SECTION "status bar tilemap", ROM0
StatusBarTilemap:
    INCBIN "res/statusbar.maintileset.tilemap.pb8"

SECTION "status bar LYC table", ROM0, ALIGN[8] ;this table will be read by the LYC handler
	;the format is like this:
	; 1: *NEXT* scaline number minus 1 for handling time
	; 2: value to write to LCDC on the *CURRENT* LYC scanline
	; this can repeat up to 128 times, but the table must start on a page boundary
	; at the end of the table, the next scanline number should be 1.
StatusBarLYCTable:
    db 8 - 1 ;at line 8 we disable sprites
    db 0 ; this is the argument for LYC 0. It isn't used rn

    db STATUS_BAR_HEIGHT - 1 ;at line 16 we turn off the window and start actually drawing the golf course using the bg
    db LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_BGON ;line 10 sprite disable

    db LYC_TABLE_END ;finish off the table
    db LCDCF_ON | LCDCF_OBJON | LCDCF_BGON ;LCDC for main golf course







