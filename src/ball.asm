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




SECTION "ball variables", WRAM0, ALIGN[4] ;force these all onto the same page
wBallY:: ;ball position relative to the course in 12.4
    dw
wBallX:: 
    dw
wBallZ::
    dw ;this is 8.8 fixed point, expressed in shadow offset pixels
wBallVY::
    dw
wBallVX:: ;ball velicities in 4.12
    dw
wBallVZ:: ;this is also 8.8 fixed point in shadow pixels per frame
    dw