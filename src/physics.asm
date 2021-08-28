INCLUDE "defines.asm"
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
    ld [hl], e ;store the velocities
    
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
    
    ret





