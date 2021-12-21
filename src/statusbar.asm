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



    ;unpack the tilemap
    ld de, $9C00 ;status bar goes at the top of the second tilemap
    ld hl, StatusBarTilemap
    ld a, 2 ;two rows of tilemap
    jp UnPB8ScreenWidth ;tail call

SECTION "status bar variables", WRAM0
wPowerMeterLevel:: ; stores how much power is stored in the power meter as a count of pixels from the right end (zero power)
    db

METER_ARROW_Y equ 4 ;the arrow starts on line 4 of the screen
ARROW_CENTER_OFFSET equ 3 ;add this to the leftmost pixel of the tile to get the center
METER_ZERO_OFFSET equ 79 ;screen-relative position of the zero point of the meters
;METER_SIZE is in defines.asm
METER_TARGET equ 23 ;23 power puts the arrow right on the target
export METER_TARGET ;also in stroke.asm


SECTION "update power meter", ROM0
UpdatePowerMeter:: ;updates the power meter arrow in shadow OAM from the level stored in wPowerMeterLevel
    ld hl, OBJ_METER ;pointer to the entry in Shadow OAM
    ld a, OAM_Y_OFS + METER_ARROW_Y
    ld [hl+], a ;write the Y coordinate

    ld a, [wPowerMeterLevel] ;grab the power level
    cpl ;invert it. Instead an `inc a`, the extra 1 will be baked into the next step
    add 1 + 8 - ARROW_CENTER_OFFSET + METER_ZERO_OFFSET ;get an OAM X position. The 8 is the OAM offset.
    ld [hl+], a ;write the X coordinate

    ld a, SPRITE_METER ;this is the sprite number
    ld [hl+], a ;write it too

    ld [hl], 0 ;this doesn't require any special flags
    
    ret








SECTION "status bar tilemap", ROM0
StatusBarTilemap:
    INCBIN "res/statusbar.maintileset.tilemap.pb8"









