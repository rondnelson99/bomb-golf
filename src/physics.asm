INCLUDE "defines.asm"

GRAVITY equ -1.5 >>12 ;acceration of gravity in shadow pixels per frame, 8.8 fixed point
POWER equ 0.25 ; shot power in a range from 0 to 1. Must be less than 1.
GREEN_POWER equ 0.5 ; shot power from the green in a range from 0 to 1. Must be less than 1.
BUNKER_POWER_COEFFICIENT equ 0.5 ;the shot's power is multiplied by this when in a bunker. Range 0-1
REGULAR_FRICTION equ 200 ;16-bit friction strength for normal ground
BUNKER_FRICTION equ 800 ;friction strength for bunkers
GREEN_FRICTION equ 150 ;friction strength for the green
OOB_FRICTON equ 300 ;friction strength for OOB areas
AIM_COEFFICIENT equ 0.2 ;defines the strength of the curve acceleration
CURVE_REDUCTION_COEFFICIENT equ 0.9 ;the curve accelerations are multiplied by this every frame when the ball is grounded
STEEP_ACCELERATION_STRENGTH  equ 2.0 ;the strength of the "steep" slope acceleration (0-8)
SLOPE_ACCELERATION_STRENGTH equ 1.5 ;the strength of the "slope" slope acceleration (0-8)

SECTION "Init Ball Physics", ROM0
InitBallPhysics:: ; use the aiming and power to get initial values for X, Y and Z velocities
    
    ld a, [wSwingAim]

    bit 7, a ;get the absolute value
    jr z, .positive
    cpl 
    inc a
.positive

    ld c, a
    
    
    ld a, [wSwingPower]
    sub c ;subtract the aim from the power
    jr nc, .noClamp
    xor a
.noClamp
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
    
    ld l, LOW(wBallVY + 1)
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


    ld e , LOW(wBallCurveX)
    
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

SECTION "Init Ball Physics on Green", ROM0
/* here's the basic plan:
 - look up the shot power in a special power curve table for the green
 - the the direction used for the cursor to split the power into X and Y components
 - set other quanitiies (aim, Z position, etc) to 0
 much simpler than the normal init
*/
InitBallPhysicsOnGreen::
    ld a, [wSwingPower] ; get the shot power
    ld h, HIGH(GreenPowerCurveLUT)
    ld l, a ;use it as an index into the power curve table
    ld c, [hl] ;get the curved power
    ; now, we need to split this into X and Y components
    ldh a, [hAimCursorDirection]
    ld h, HIGH(AimCursorXTable)
    ld l, a ; get the sin and cos components of the direction
    ld e, [hl] ; get the X component (will be preserved)
    dec h
    assert AimCursorXTable - 256 == AimCursorYTable
    ld h, [hl] ; get the Y component 

    call SignedHTimesC ;multiply the power by the Y component
    ; hl now contains the Y velocity in signed 4.12
    ld d, h
    ld h, e
    ld e, l ; move VY into de and the X multiplier into h

    call SignedHTimesC ;multiply the power by the X component
    ; hl now contains the X velocity in signed 4.12
    ld a, l
    ld b, h
    ; now we have the initial Y and X velocities in de and ba, respectively
    ld hl, wBallVY
    ld [hl], e
    inc l
    ld [hl], d ;store the Y velocity
    ld l, LOW(wBallVX)
    ld [hl+], a
    ld [hl], b ;store the X velocity

    ; now we just need to sero other quantities
    xor a
    ld l, LOW(wBallZ)
    ld [hl+], a
    ld [hl+], a ;set the Z position to 0
    assert wBallZ + 2 == wBallCurveY
    ld [hl+], a
    ld [hl+], a ;zero wBallCurveY
    ld l, LOW(wBallCurveX)
    ld [hl+], a
    ld [hl+], a ;zero wBallCurveX
    ld l, LOW(wBallVZ)
    ld [hl+], a
    ld [hl+], a ;zero wBallVZ

    ret





SECTION "Green power curve table", ROM0, ALIGN[8] ;use a table to define a power curve so that I can easily make any function I want
GreenPowerCurveLUT: ; this is 4.4 unsigned fixed point
FOR I, METER_SIZE
    db div(mul(I*1.0, POWER<<4), METER_SIZE*1.0) >>12   ;linear curve
ENDR

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
    db round(mul(-127.0,cos(I * (1.0 / 16)))) >>16
    db round(mul(127.0,sin(I * (1.0 / 16)))) >>16
ENDR

SECTION "Update Ball Physics", ROM0

/* The basic structure for the physics engine is this: 
 - Apply the XY velocities to the ball position
 - Apply the XY curve accelerations to the velocities

 - Check whether the ball is grounded, and branch
 if airborne:
    - Apply the Z velocity to the Z position
    - Apply the Gravity acceleration to the Z velocity 
if grounded:
    - Curve accelerations decrese exponentially
    - The stored Terrain Type variable is used to determine the friction coefficient
    - Friction is applied as a constant deceleration to the velocities
*/
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
    ld l, LOW(wBallCurveY)
    ld a, [hl+]
    ld b, [hl]
    ld l, LOW(wBallVY)
    add [hl]
    ld [hl+], a
    ld a, [hl]
    adc b
    ld [hl+], a

    ld l, LOW(wBallVX + 1)
    ld e, LOW(wBallX)

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

    ;now add the X curve acceleration
    ld l, LOW(wBallCurveX)
    ld a, [hl+]
    ld b, [hl]
    ld l, LOW(wBallVX)
    add [hl]
    ld [hl+], a
    ld a, [hl]
    adc b
    ld [hl+], a

    ld e, LOW(wBallZ)
    ld l, LOW(wBallVZ) ;both of these are 8.8 fixed point

    ;now we check whether the ball is in the air to decide what comes next
    ld a, [de]
    ld b, a
    inc e
    ld a, [de]
    or b

    jr z, Grounded

Aerial: 
    dec e
    ;now de points to wBallZ
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

    ; now, the curve accelerations experience exponential decay
    ld l, LOW(wBallCurveX + 1)
    ld b, [hl]
    dec l
    ld c, [hl] ;get wBallCurveX into bc
    ld a, CURVE_REDUCTION_COEFFICIENT >> 8
    call SignedBCTimesA
    ;now the reduced curve acceleration is in AH
    ld de, wBallCurveX + 1
    ld [de], a
    dec e
    ld a, h
    ld [de], a ;store it

    ld e, LOW(wBallCurveY + 1)
    ld a, [de]
    ld b, a
    dec e
    ld a, [de]
    ld c, a ;get wBallCurveY into bc
    ld a, CURVE_REDUCTION_COEFFICIENT >> 8
    call SignedBCTimesA
    ;now the reduced curve acceleration is in AH
    ld [wBallCurveY + 1], a
    ld a, h
    ld [wBallCurveY], a ;store them

    ; next, we check if the ball is on a green slope, and apply appropriate slope acceleration if so

    assert TERRAIN_GREEN_STEEP_RIGHT == $50
    assert TERRAIN_GREEN_SLOPE_UP_RIGHT == $5F
    ldh a, [hTerrainType]
    sub TERRAIN_GREEN_STEEP_RIGHT
    jr c, .doneGreenSlope
    cp TERRAIN_GREEN_SLOPE_UP_RIGHT - TERRAIN_GREEN_STEEP_RIGHT
    jr nc, .doneGreenSlope

    ; if we get here, then the ball is on a green slope, so we need to apply a slope acceleration

    ; We will fetch the slope acceleration from a table, which will be indexed by the terrain type
    add a, a ;double the index since each entry is 2 bytes
    ld d, HIGH(SlopeAccelerationTable)
    ld e, a
    ld hl, wBallVY ; low byte of Y velocity

    ; add the y acceleration
    ld a, [de] ;get the low byte of Y acceleration
    ld b, a ;store it
    add [hl] ;add it to the Y velocity
    ld [hl+], a
    ld a, 0
    adc [hl] ;add it to the high byte of the Y velocity
    bit 7, b ;check the sign of the acceleration
    jr z, .positiveY
    dec a
.positiveY
    ld [hl], a

    ;now do the same for the X acceleration
    inc e
    ld l, LOW(wBallVX)
    ld a, [de]
    ld b, a
    add [hl]
    ld [hl+], a
    ld a, 0
    adc [hl]
    bit 7, b
    jr z, .positiveX
    dec a
.positiveX
    ld [hl], a

.doneGreenSlope


    ;subtract friction (constant deceleration) from the velocities

    ;we do this by dividing a constant representing the friction (this willv ary based on terrain) by the magnitude of our velocity.
    ;then we can multiply this by each component of our velocity to get the friction vector, which we subtract away.

    ;point hl to the high byte of wBallVY
    ld hl, wBallVY + 1

    ld a, [hl+] ;high byte of Y velocity
    ld l, LOW(wBallVX + 1)
    ld b, [hl] ;high byte of X velocity
    assert wBallVY + 4 == wBallVX

    ld e, l
    ld d, h ;get hl into de so it can be preserved
    ;de points to the high byte of wBallVX
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
    jr z, .terrainBunker ; temporary since water will eventually be handled differently
    dec a
    assert TERRAIN_BUNKER == 4
    jr z, .terrainBunker

    ; if the terrain is between $50 and $5F, it is a green slope, so it has the same friction as regular green

    assert TERRAIN_GREEN_STEEP_RIGHT == $50
    assert TERRAIN_GREEN_SLOPE_UP_RIGHT == $5F
    ldh a, [hTerrainType]
    cp TERRAIN_GREEN_STEEP_RIGHT
    error c
    cp TERRAIN_GREEN_SLOPE_UP_RIGHT
    error nc

    jr .terrainGreen

    

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

    dec e ; de points to wBallVX

    ; Our registers are now in this state:
    ; a and b are trash
    ; c contains the vector magnitude, which we need to preserve
    ; de points to wBallVX
    ; hl contains the X friction, which will be subtracted from wBallVX
    
    ld a, [de]
    sub l
    ld [de], a 
    inc e
    ld a, [de]
    ld b, a ; save the high byte of the velocity to compare signs
    sbc h
    ld [de], a 

    xor b
    rla ; check if the sign changed
    jr nc, .noClampX
    ;if the sign changed, clamp the whole word to 0.
.clampX
    xor a
    ld [de], a
    dec e
    ld [de], a
    inc e ;gotta leave e with the same value it would have otherwise
.noClampX

    ld e, LOW(wBallVY+1)


    ld a, [de]
    call SignedATimesC

    ;now hl contains the Y friction, which will be subtracted from wBallY
    dec e
    ld a, [de]
    sub l
    ld [de], a 
    inc e
    ld a, [de]
    ld b, a ; save the high byte of the velocity to compare signs
    sbc h
    ld [de], a

    xor b
    rla ; check if the sign changed
    jr nc, .noClampY
    ;if the sign changed, clamp the whole word to 0 since the low byte is ignored when adding the velocities anyways.
.clampY
    xor a
    ld [de], a
    dec e
    ld [de], a
    inc e ;gotta leave e with the same value it would have otherwise
.noClampY


    ; now, de still points to the ball variable area, but not hl. 
    

    ret

SECTION "Slope Acceleration Table", ROM0, ALIGN[8]
; These are 0.8 fixed point signed numbers which get added to the velocities when the ball is on a slope
; Each entry is Y acceleration followed by X acceleration
SlopeAccelerationTable:
    FOR I, 0, 1.0, 1.0 / 8
        db LOW(mul(STEEP_ACCELERATION_STRENGTH, sin(I)) >> 12)
        db LOW(mul(STEEP_ACCELERATION_STRENGTH, cos(I)) >> 12)
    ENDR
    FOR I, 0, 1.0, 1.0 / 8
        db LOW(mul(SLOPE_ACCELERATION_STRENGTH, sin(I)) >> 12)
        db LOW(mul(SLOPE_ACCELERATION_STRENGTH, cos(I)) >> 12)
    ENDR







