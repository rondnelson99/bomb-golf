INCLUDE "defines.asm"

GRAVITY equ -5.0 >>12 ;acceration of gravity in shadow pixels per frame, 8.8 fixed point

SECTION "Init Ball Physics", ROM0
InitBallPhysics:: ; use the aiming and power to get initial values for X, Y and Z velocities
    ld a, [wSwingPower]
    ;look up the shot power in the power curve table
    ld l, a
    ld h, HIGH(PowerCurveLUT)
    assert LOW(PowerCurveLUT) == 0
    ld c, [hl] ;get the power and keep it for multiplication soon

    ld a, [wArrowFacingDirection] ;range 0-15 in multiples of 22.5 degrees from vertical
    add a, a ;this is an array of 2-byte structs, so double the index
    ld e, a
    ld d, HIGH(DirectionTableLUT)
    assert LOW(DirectionTableLUT) == 0
    ld a, [de] ; This is the signed coefficient to get the Y velocity
    
    call SignedATimesC
    ; hl now contains the initial Y velocity in signed 4.12
    inc e
    ld a, [de] ;grab the coefficient for the X velocity
    ld d, h ;stash out Y velocity away for a moment
    ld e, l
    
    ; c (shot power) is still intact
    call SignedATimesC
    ; h now contains initial X velocity 
    ld a, h
    ld b, l
    ld hl, wBallVX + 1 ;high byte of X velocity
    ld [hl-], a
    ld [hl], b
    assert wBallVX - 2 == wBallVY
    dec l
    ld [hl], d
    dec l
    ld [hl], e ;store the YX velocities

    ; now do the Z velocity
    ; The initial Z velocity is shot power times a constant for each club
    ; shot power is still in C
    ld h, 25 ;This wil be the constant for now

    call HTimesC ;unsigned this time
    ;divide by 4 to get a more reasonable range
    ld a, l
    srl h
    rra
    srl h
    rra

    ;hl now contains the inital Z velocity in 8.8
    ld [wBallVZ], a
    ld a, h
    ld [wBallVZ + 1], a ;store the Z velocity

    ld hl, wBallZ + 1 ;set the Z position
    xor a
    ld [hl-], a
    ld [hl], 1 ;set the Z position to 1/256, because if The Z position is zero then the grounded codepath will be used


    
    ret

    







SECTION "power curve table", ROM0, ALIGN[8] ;use a table to define a power curve so that I can easily make any function I want
PowerCurveLUT: ; this is 4.4 unsigned fixed point
FOR I, METER_SIZE
    db div(mul(I*1.0, 15.0), METER_SIZE*1.0) >>12   ;linear curve
ENDR

SECTION "Direction Ratio Table", ROM0, ALIGN[8] ;this represents a fractional (0.8 fixed point) signed Y coefficient and signed X coefficient for each of the initial velocities
;note that 0 is vertical, not rightward.
DirectionTableLUT:
FOR I, 16
    db round(mul(-127.0,cos(I * (65536 / 16) <<16 ))) >>16
    db round(mul(127.0,sin(I * (65536 / 16) <<16 ))) >>16
ENDR

SECTION "Update Ball Physics", ROM0

UpdateBallPhysics:: 
    ;add the 4.12 (ignore the low byte) velocities to the 12.4 positions

    ld hl, wBallY 
    ld de, wBallVY + 1 ;skip to the high byte

    ld a, [de]
    ld b, a
    rla 
    sbc a ;sign extend
    ld c, a

    ld a, [hl]
    add b
    ld [hl+], a

    ld a, [hl]
    adc c
    ld [hl+], a
    
    inc e
    inc e

    ld a, [de]
    ld b, a
    rla 
    sbc a ;sign extend
    ld c, a

    ld a, [hl]
    add b
    ld [hl+], a

    ld a, [hl]
    adc c
    ld [hl+], a

    inc e

    assert wBallY + 4 == wBallZ
    assert wBallVY + 4 == wBallVZ
    ;hl now points to wBallZ
    ;de now points to wBallVZ
    ;both of these are 8.8 fixed point

    ;now we check whether the ball is in the air to decide what comes next
    ld a, [hl+]
    or [hl]

    jr z, Grounded

Aerial: 
    dec l ;now hl points to wBallZ
    ;now we just add them
    ld a, [de]
    add [hl]
    ld [hl+], a
    inc e
    ld a, [de] 
    adc [hl] ;if this doesn't carry and the velocity is negative, then we just passed Z of 0, and should clip.
    jr c, .noClip

    ld b, a
    ld a, [de] ;get the high byte of the velocity again
    rla ;rotate sign into carry
    ld a, b
    jr nc, .noClip
.clip
    xor a ;zero the Z position
    dec l
    ld [hl+], a

.noClip
    ld [hl], a

    dec e ;point de back to wBallVZ
    ;add acceleration of gravity to the velocity
    ld a, [de]
    add LOW(GRAVITY)
    ld [de], a
    inc e
    ld a, [de]
    adc HIGH(GRAVITY)
    ld [de], a


Grounded:






    
    ret





