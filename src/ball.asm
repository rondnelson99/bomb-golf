INCLUDE "defines.asm"

BALL_Y_OFFSET equ 4 ;offset from the top-left of the sprite to the center of the ball
BALL_X_OFFSET equ 4

SECTION "Draw Ball", ROM0
DrawBall:: ;draws the ball on screen
    ld hl, wBallY ; this is 12.4, but we want to convert to integer
    ld a, [hl+] ;low byte
    ld b, a
    ld a, [hl+] ;high byte
    cp 16 ;make sure it's within the 256 px tilemap range
    jr nc, .hide ;and hide it if it's not
    xor b
    and $0f
    xor b ;masked merge
    swap a
    ;store it in c until we're ready to write it
    ld c, a
    ;subtract the camera position
    ldh a, [hSCY]
    cpl ; invert it. The inc a is bakes into the next add
    add 1 + OAM_Y_OFS - BALL_Y_OFFSET ;convert to OAM position
    add c
    cp STATUS_BAR_HEIGHT - 8 + OAM_Y_OFS;if the sprite is fully hidden by the status bar, don't draw it
    jr c, .hide
    ld c, a

    ;now for the X coordinate
    ;do the whole fetch and masked merge thing again
    ld a, [hl+] ;low byte
    ld b, a
    ld a, [hl+] ;high byte
    cp 16 ;make sure it's within the 256 px tilemap range
    jr nc, .hide ;and hide it if it's not
    xor b
    and $0f
    xor b ;masked merge
    swap a
    ;aubtract the camera position
    ld hl, hSCX
    sub [hl]
    add OAM_X_OFS - BALL_X_OFFSET ;convert to OAM position

    ;now we can clobber hl and start writing these
    ld hl, OBJ_BALL ;the entry in Shadow OAM
    ld [hl], c ;y coordinate first
    inc l ;shadow OAM is aligned so this is fine
    ld [hl+], a ;X coordinate
    ld a, SPRITE_BALL ;tile number
    ld [hl+], a
    ld [hl], OAMF_PAL1 ; this uses OBP1 for for a light blue on CGB

    ret



.hide
    xor a ;zero the Y coordinate in OAM to hide it
    ld [OBJ_BALL + OAMA_Y], a
    ret






SECTION "ball variables", WRAM0
wBallY:: ;ball position relative to the course in 12.4
    dw
wBallX:: 
    dw
wBallVY::
    db
wBallVX:: ;ball velicities in 4.4
    db