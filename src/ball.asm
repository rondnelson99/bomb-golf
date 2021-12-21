INCLUDE "defines.asm"

BALL_Y_OFFSET equ -4 ;offset from the center of the ball to the top-left of the sprite 
BALL_X_OFFSET equ -4

SHADOW_Y_OFFSET equ -3 ;offset from the center of the ball to the top-left of the shadow sprite
SHADOW_X_OFFSET equ -3 

SECTION "Draw Ball", ROM0
DrawBall:: ;draws the ball on screen
    ld hl, wBallY ; this is 12.4, but we want to convert to integer
    ld de, OBJ_BALL
    lb bc, BALL_Y_OFFSET, BALL_X_OFFSET
    
    call RenderSprite124

    ;now we just need to set the flags and tile number, which hl points to
    ld a, SPRITE_BALL ;tile number
    ld [hl+], a
    ld [hl], OAMF_PAL1 ; this uses OBP1 for for a light blue on CGB


    ld a, [wBallZ + 1] ;this is 8.8 so the high byte is the integer part
    add SHADOW_Y_OFFSET
    ld b, a ;Y offset
    sra a ;X offset is divided by 2. This makes the shadow be at a fixed south-by-southeast direction
    add SHADOW_X_OFFSET - SHADOW_Y_OFFSET / 2
    ld c, a
    
    
    ld hl, wBallY
    ld de, OBJ_SHADOW

    call RenderSprite124

        ;now we just need to set the flags and tile number, which hl points to
    ld a, SPRITE_SHADOW ;tile number
    ld [hl+], a
    ld [hl], 0 ; no special flags

    ret

SECTION "Draw Ball on Green", ROM0
DrawBallOnGreen:: ;draws the ball on screen
    ;Params: H - High byte of the ball attribute address


    ;subtrant the green coordinate from the ball coordinate
    ld l, LOW(wBallY)
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
    jr c, .hide


    
.draw
    ;if all those checks passed, then we can draw the ball. The 12.4 Y coordinate is stored in BC, and the 12.4 X coordinate is stored in DE
    ld hl, OBJ_BALL

    ld a, c
    rr b
    rra 
    add OAM_Y_OFS
    ld [hl+], a ;write the Y coordinate to the OAM

    ld a, e
    rr d
    rra
    add OAM_X_OFS
    ld [hl+], a ;write the X coordinate to the OAM
    ld a, SPRITE_BALL ;tile number
    ld [hl+], a
    xor a
    ld [hl+], a ;no flags

    ;the ball doesn't get a shadow on the green
    ret

.hide
    ;hide the ball by zeroing its Y coordinate
    xor a
    ld [OBJ_BALL], a
    ret

    

    
    




SECTION "ball variables", WRAM0, ALIGN[8] ;align so that each ball shares the same low byte for each variable
wBallY:: ;ball position relative to the course in 12.4
    dw
wBallX:: 
    dw
wBallZ::
    dw ;this is 8.8 fixed point, expressed in shadow offset pixels
wBallCurveY:: ;this is the curve acceleration for when they dob't get their aim perfect
    dw ;it's not subject to friction
wBallVY::
    dw
wBallCurveX::
    dw
wBallVX:: ;ball velicities in 4.12
    dw
wBallVZ:: ;this is also 8.8 fixed point in shadow pixels per frame
    dw
