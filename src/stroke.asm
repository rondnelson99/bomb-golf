INCLUDE "defines.asm"

POWER_CHARGE_SPEED equ 1 ;pixels per frame of power charging
AIM_METER_SPEED equ 2 ; pixels per frame of the meter decreasing before the player locks in their aim

SECTION "Check Swing", ROM0
CheckSwing:: ;checks if the user is trying to start a swing. If so, it takes over from the main loop. destroys everything
    ldh a, [hPressedKeys] ; check if A is being pressed
    assert PADB_A == 0
    rrca ;rotate the A button into carry
    ret nc ;we're done here if they're not swinging

    ;otherwise, start a swing
    xor a
    ld [wPowerMeterLevel], a ;start with 0 power

    inc a ;ld a, 1
    assert POWER_CHARGE_SPEED == 1
    ld [wPowerChargeSpeed], a ;charge at 1 px/frame

    ;draw the power meter
    call UpdatePowerMeter

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
    rst WaitVBlank ;queue up new input and stuff for the next loop

SwingLoop: ;this replaces the main loop
    ldh a, [hPressedKeys]
    assert PADB_A == 0
    rrca ;rotate the A button into carry
    jr c, .finishSwingPower ;move on to the next stage of the swing if they're selecting their power here

.updatePowerLevel
    ; otherwise, keep incrementing the power meter
    ld a, [wPowerChargeSpeed]
    ld hl, wPowerMeterLevel
    add [hl] ;add the level and charge speed
    ; store it
    ld [hl], a

    cp METER_SIZE - 1 ;is it greater than or equal to METER_SIZE - 1 (max meter level) or less than 0?
    jr c, .skipAdjust ;if so, adjust it

    ;check if the power meter underflowed of overflowed by checking of the charge speed is positive or negative
    ld a, [wPowerChargeSpeed]
    bit 7, a
    jp nz, FinishSwing ;if they didn't even do a swing, they just gain a point

    ;otherwise they've passed max power and the meter should now go down
    cpl 
    inc a ;invert the charge speed
    ld [wPowerChargeSpeed], a
.skipAdjust

    ;draw the power meter
    call UpdatePowerMeter

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
    rst WaitVBlank
    jr SwingLoop

.finishSwingPower
    ld a, [wPowerMeterLevel]
    ld [wSwingPower], a ;store the player's power

    ;now make a copy of the sprite that shows the power level so they can see what their power was
    assert OBJ_METER + 4 == OBJ_METER_COPY ;because they're right next to each other and we're only copying 4 bytes, we can use registers to store the bytes we're copying
    
    ld hl, OBJ_METER
    ld a, [hl+]
    ld b, [hl]
    inc l
    ld c, [hl]
    inc l
    ld d, [hl]
    inc l
    ld [hl+], a
    ld [hl], b
    inc l
    ld [hl], c
    inc l
    ld [hl], d ;such optimization, very cool

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
    rst WaitVBlank ;queue up new input and stuff for the next loop
AimLoop: ;This also replaces the main loop
    ldh a, [hPressedKeys]
    assert PADB_A == 0
    rrca ;rotate the A button into carry
    jr c, .finishSwingAim ;move on if they've chosen their aim by pressing A

.updateAimLevel
    ld hl, wPowerMeterLevel
    ld a, [hl]
    sub AIM_METER_SPEED ;make the meter go down at the set speed
    ld [hl], a 

    jr nc, .skipAdjust 
.adjustAim ;if the pointer just passed the end of the meter (resulting in a borrow), then clamp it to zero and move on
    xor a
    ld [hl], a
    jr .finishSwingAim
.skipAdjust

    call UpdatePowerMeter

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
    rst WaitVBlank
    jr AimLoop

.finishSwingAim
    ;calculate the aim as relative to the target on the power meter
    ld a, [wPowerMeterLevel] ;get the sopt that they're aiming at
    sub METER_TARGET ;this is the power level that put the cursor right on the target
    ld [wSwingAim], a

    call ClearArrowSprite
    ; now get ready to move to the physics loop
    call InitBallPhysics

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
    rst WaitVBlank ;queue up new input and stuff for the next loop
PhysicsLoop: ; this takes over from the main loop until the ball stops moving
    call UpdateBallPhysics
    ld hl, wBallY
    call ScrollToSprite124
    call DrawBall

    ;check if we're over water
    ld hl, wBallY
    call LookUpTerrain
    ldh [hTerrainType], a

    ;check if the velocity is zero
    ld hl, wBallVY
    ld a, [hl+]
    or [hl]
    assert wBallVY + 2 == wBallVX
    inc l ;the ball variables are all on the same page
    or [hl]
    inc l
    or [hl]

    jr z, FinishSwing

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
    rst WaitVBlank
    jr PhysicsLoop




FinishSwing: ;I'll wrap up whatever here like incrementing the player's score.
    ret

SECTION "swing HRAM", HRAM
hTerrainType:: ;holds the terrain ID that the ball is over
    db

SECTION "swing variables", WRAM0
wPowerChargeSpeed: ;charge speed in px/frame
    db
wSwingPower:: ;this is set once the player has locked in their power. The range is the length of the power meter in px
    db
wSwingAim:: ;this is set once the player has lockd their aim. it's negative if the ball should curve left and vice-versa
    db







