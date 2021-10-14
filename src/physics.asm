INCLUDE "defines.asm"

GRAVITY equ -5.0 >>12 ;acceration of gravity in shadow pixels per frame, 8.8 fixed point
POWER equ 0.4 ; shot power in a range from 0 to 1. Must be less than 1.
BUNKER_POWER_COEFFICIENT equ 0.5 ;the shot's power is multiplied by this when in a bunker. Range 0-1
REGULAR_FRICTION equ 200 ;16-bit friction strength for normal ground
BUNKER_FRICTION equ 800 ;friction strength for bunkers
GREEN_FRICTION equ 150 ;friction strength for the green
OOB_FRICTON equ 300 ;friction strength for OOB areas
SECTION "Init Ball Physics", ROM0
InitBallPhysics:: ; use the aiming and power to get initial values for X, Y and Z velocities
    ld a, [wSwingPower]
    ;look up the shot power in the power curve table
    ld l, a
    ld h, HIGH(PowerCurveLUT)
    assert LOW(PowerCurveLUT) == 0
    ld c, [hl] ;get the power and keep it for multiplication soon

    ldh a, [hTerrainType]
    cp TERRAIN_BUNKER ;If the ball's on a bunker
    jr nz, .notBunker
    ld h, BUNKER_POWER_COEFFICIENT >> 8 ; reduce the power using this 0.8 FP number
    call HTimesC
    ld c, h
.notBunker

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
    assert wBallVX - 4 == wBallVY
    dec l
    dec l
    dec l
    ld [hl], d
    dec l
    ld [hl], e ;store the YX velocities

    ; now do the Z velocity
    ; The initial Z velocity is shot power times a constant for each club
    ; shot power is still in C
    ld h, 60 ;This wil be the constant for now

    call HTimesC ;unsigned this time
    ;divide by 4 to get a more reasonable range
    ld a, l
    srl h
    rra
    srl h
    rra

    ;ha now contains the inital Z velocity in 8.8
    ld [wBallVZ], a
    ld a, h
    ld [wBallVZ + 1], a ;store the Z velocity

    ld hl, wBallZ + 1 ;set the Z position
    xor a
    ld [hl-], a
    ld [hl], 1 ;set the Z position to 1/256, because if The Z position is zero then the grounded codepath will be used

    ;now do the curve if they didn't center the aim
    ld a, [wSwingAim]
    ;this is positive if the ball should curve clockwise
    ;so we multiply the initial X velocity by this, and make that the curve Y acceleration
    ;but then we need to invert this before multiplying by the Y velocity to get the curve X acceleration

    ld de, wBallCurveY

    ;first, let's scale it according to a LUT
    ld l, a
    ld h, HIGH(AimCurveLUT)
    assert LOW(AimCurveLUT) == 0
    ld c, [hl]
    ld a, [wBallVX + 1] ;high byte
    call SignedATimesSignedC
    ld a, l ;low byte of product
    ld [de], a
    inc e
    ld a, h ;high byte
    ld [de], a
    inc e

    inc e
    inc e
    assert wBallCurveY + 4 == wBallCurveX

    
    xor a
    sub c
    ld c, a ;invert C

    ld a, [wBallVY + 1] ;high byte
    call SignedATimesSignedC
    ld a, l ;low byte
    ld [de], a
    inc e
    ld a, h ;high byte
    ld [de], a

    


    ret

    

AIM_COEFFICIENT equ 0.5
SECTION "Aim Curve Scaling Table", ROM0, ALIGN[8] ; This scales the aim curve acceleration 

;this is 0.8 FP, which is used as a coefficient on the velocity components to get a perpendicular acceleration
AimCurveLUT: ;this is a signed table
    FOR I, 0, 128.0, 1.0
        db mul(I>>8,AIM_COEFFICIENT)>>8
    ENDR
    FOR I, -128.0, 0, 1.0
        db mul(I>>8,AIM_COEFFICIENT)>>8
    ENDR




SECTION "power curve table", ROM0, ALIGN[8] ;use a table to define a power curve so that I can easily make any function I want
PowerCurveLUT: ; this is 4.4 unsigned fixed point
FOR I, METER_SIZE
    db div(mul(I*1.0, POWER<<4), METER_SIZE*1.0) >>12   ;linear curve
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

    ld de, wBallY 
    ld hl, wBallVY + 1 ;skip to the high byte
    ;start with Y velocity
    ld a, [hl-]
    ld b, a
    rla 
    sbc a ;sign extend
    ld c, a

    ld a, [de]
    add b
    ld [de], a
    inc e

    ld a, [de]
    adc c
    ld [de], a

    ;now add the Y curve acceleration
    dec l
    dec l
    ld a, [hl+]
    assert wBallVY - 2 == wBallCurveY
    ld b, [hl]
    inc l
    add [hl]
    ld [hl+], a
    ld a, [hl]
    adc b
    ld [hl+], a

    inc l
    inc l
    inc l
    assert wBallVY + 4 == wBallVX
    inc e
    assert wBallY + 2 == wBallX

    ;do X velocity
    ld a, [hl-]
    ld b, a
    rla 
    sbc a ;sign extend
    ld c, a
    ld a, [de]
    add b
    ld [de], a
    inc e
    ld a, [de]
    adc c
    ld [de], a
    inc e

    ;now add the X curve acceleration
    dec l
    dec l
    ld a, [hl+]
    assert wBallVX - 2 == wBallCurveX
    ld b, [hl]
    inc l
    add [hl]
    ld [hl+], a
    ld a, [hl]
    adc b
    ld [hl+], a


    assert wBallY + 4 == wBallZ
    assert wBallVY + 6 == wBallVZ
    ;de now points to wBallZ
    ;hl now points to wBallVZ
    ;both of these are 8.8 fixed point

    ;now we check whether the ball is in the air to decide what comes next
    ld a, [de]
    ld b, a
    inc e
    ld a, [de]
    or b

    jr z, Grounded

Aerial: 
    dec e ;now de points to wBallZ
    ;hl points to wBallVZ
    ;now we just add them
    ld a, [de]
    add [hl]
    ld [de], a
    inc e
    inc l
    ld a, [de] 
    adc [hl] ;if this doesn't carry and the velocity is negative, then we just passed Z of 0, and should clip.
    jr c, .noClip

    ld b, a
    ld a, [hl] ;get the high byte of the velocity again
    rla ;rotate sign into carry
    ld a, b
    jr nc, .noClip
.clip
    xor a ;zero the Z position
    dec e
    ld [de], a
    inc e

.noClip
    ld [de], a

    dec l ;point hl back to wBallVZ
    ;add acceleration of gravity to the velocity
    ld a, [hl]
    add LOW(GRAVITY)
    ld [hl+], a
    ld a, [hl]
    adc HIGH(GRAVITY)
    ld [hl], a
    
    
    
    ret


Grounded:
    ;de points to wBallZ + 1
    ;hl points to wBallVZ

    ;subtract friction (constant deceleration) from the velocities

    ;we do this by dividing a constant representing the friction (this willv ary based on terrain) by the magnitude of our velocity.
    ;then we can multiply this by each component of our velocity to get the friction vector, which we subtract away.

    ;this is 8-bit logic so we only care about the low bytes
    ld a, l
    sub 5
    ld l, a ;point hl to the high byte of wBallVY
    assert wBallVZ - 6 == wBallVY

    ld a, [hl+] ;high byte of Y velocity
    inc l
    inc l
    inc l
    ld b, [hl] ;high byte of X velocity
    assert wBallVY + 4 == wBallVX

    ld e, l
    ld d, h ;get hl into de so it can be preserved

    call GetVectorMagnitude

    ;now we get our friction constant
    ;this varies by terrain
    ld c, a ;store away the vector magnitude
    ldh a, [hTerrainType]
    and a ;cp TERRAIN_NONE
    assert TERRAIN_NONE == 0
    jr z, .terrainNormal
    dec a
    assert TERRAIN_GREEN == 1
    jr z, .terrainGreen
    dec a
    assert TERRAIN_OOB == 2
    jr z, .terrainOOB
    dec a
    error z ;no water here
    dec a
    assert TERRAIN_BUNKER == 4
    error nz

.terrainBunker
    ld hl, BUNKER_FRICTION
    jr .gotFrictionConstant
.terrainOOB
    ld hl, OOB_FRICTON
    jr .gotFrictionConstant
.terrainGreen
    ld hl, GREEN_FRICTION
    jr .gotFrictionConstant
.terrainNormal
    ld hl, REGULAR_FRICTION ;friction for regular ground

    


.gotFrictionConstant
    
    ;do the division
    call HLOverC

    ;the quotient is in hl now, but we'll assume this will be less than 256, so we only care about l

    ;now de points to the high byte of wBallVX

    ld a, [de]
    ld c, l 

    call SignedATimesC

    ;now hl contains the X friction, which will be subtracted from wBallVX
    dec e
    ld a, [de]
    sub l
    ld [de], a 
    inc e
    ld a, [de]
    sbc h
    ld [de], a 
    jr nz, .noClampX
    ;if the sign changed, clamp the whole word to 0 since the low byte is ignored when adding the velocities anyways.
.clampX
    xor a
    dec e
    ld [de], a
    inc e ;gotta leave e with the same value it would have otherwise
.noClampX

    ;and do the Y friction
    dec e
    dec e
    dec e
    dec e ;point e to the high byte of wBallVY
    assert wBallVX - 4 == wBallVY


    ld a, [de]
    call SignedATimesC

    ;now hl contains the Y friction, which will be subtracted from wBallY
    dec e
    ld a, [de]
    sub l
    ld [de], a 
    inc e
    ld a, [de]
    sbc h
    ld [de], a
    jr nz, .noClampY
    ;if the sign changed, clamp the whole word to 0 since the low byte is ignored when adding the velocities anyways.
.clampY
    xor a
    dec e
    ld [de], a
    inc e ;gotta leave e with the same value it would have otherwise
.noClampY





















    







    
    ret





