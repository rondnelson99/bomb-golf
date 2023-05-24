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
    ; set the swing bit of the game state
    ldh a, [hGameState]
    or STROKE_FLAG
    ldh [hGameState], a

    xor a
    ldh [hSwingStep], a ; start with the first swing step (power)
    ld [wPowerMeterLevel], a ;start with 0 power

    inc a ;ld a, 1
    assert POWER_CHARGE_SPEED == 1
    ld [wPowerChargeSpeed], a ;charge at 1 px/frame

    ;draw the power meter
    call UpdatePowerMeter

    ret

SECTION "Update Swing", ROM0
UpdateSwing:: ;called from main loop during a swing
    ; Run appriopriate code based on the swing step
    ldh a, [hSwingStep]
    and a ;Check for step 0
    jr z, .powerCharge

    dec a ;check for step 1
    jr z, Aim

    dec a ;check for step 2
    jr z, Physics

    ;Something's wrong if we get here
    rst Crash


.powerCharge
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
    jp UpdatePowerMeter ; tail call

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

    ; go to the next swing step. This is aiming, unless the player is on the green, in which case it's physics
    ldh a, [hGameState]
    and GREEN_VIEW_FLAG
    jr nz, .onGreen
.notGreen
    ld a, SWING_STEP_AIM
    ldh [hSwingStep], a
    ret

.onGreen
    call InitBallPhysicsOnGreen

    ld a, SWING_STEP_PHYSICS
    ldh [hSwingStep], a
    ret

Aim: 
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

    jp UpdatePowerMeter ; tail call

.finishSwingAim
    ;calculate the aim as relative to the target on the power meter
    ld a, [wPowerMeterLevel] ;get the sopt that they're aiming at
    sub METER_TARGET ;this is the power level that put the cursor right on the target
    ld [wSwingAim], a

    call ClearArrowSprite
    ; now get ready to move to the physics loop
    

    call InitBallPhysics
    
    ; increment the swing step
    ld a, SWING_STEP_PHYSICS
    ldh [hSwingStep], a

    ret

Physics: ; runs every frame until the ball stops moving
    call UpdateBallPhysics

    ; if we're not on the green right now, scroll to the ball
    ldh a, [hGameState]
    and GREEN_VIEW_FLAG
    jr nz, .onGreen
    ld hl, wBallY 
    call ScrollToSprite124
.onGreen
    

    ; check if the velocity is extremely low (X and Y magnitude both less than 1/16 px/frame)
    ; this means that both the high bytes of X and Y velocity are either 0 or FF
    ld hl, wBallVY + 1

    ld a, [hl]
    inc a
    and %11111110 ; sets z flag if the high byte of Y velocity is 0 or FF
    
    jr nz, DontFinishSwing

    ld l, LOW(wBallVX + 1)
    ld a, [hl]
    inc a
    and %11111110 ; sets z flag if the high byte of X velocity is 0 or FF
 
    jr z, FinishSwing

DontFinishSwing:
    ret




FinishSwing: ;I'll wrap up whatever here like incrementing the player's score.

    ; increment the player score
    call IncrementScore

    ; clear the swing bit of the game state
    ldh a, [hGameState]
    and ~ STROKE_FLAG
    ldh [hGameState], a
    ret


SECTION "swing HRAM", HRAM
hTerrainType:: ;holds the terrain ID that the ball is over
    db
hOldTerrainType:: ;holds the terrain ID that the ball was over last frame
    db
hSwingStep: ; 0 = power, 1 = aim, 2 = physics
    db

SWING_STEP_POWER equ 0
SWING_STEP_AIM equ 1
SWING_STEP_PHYSICS equ 2
EXPORT SWING_STEP_POWER, SWING_STEP_AIM, SWING_STEP_PHYSICS

SECTION "swing variables", WRAM0
wPowerChargeSpeed: ;charge speed in px/frame
    db
wSwingPower:: ;this is set once the player has locked in their power. The range is the length of the power meter in px
    db
wSwingAim:: ;this is set once the player has lockd their aim. it's negative if the ball should curve left and vice-versa
    db







