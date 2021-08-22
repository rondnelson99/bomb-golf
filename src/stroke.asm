INCLUDE "defines.asm"

POWER_CHARGE_SPEED equ 1 ;pixels per frame of power charging

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
    ld [wPowerChargeSpeed], a ;charge at 1 px/frame

SwingLoop: ;this replaces the main loop
    rst WaitVBlank

    ldh a, [hPressedKeys]
    assert PADB_A == 0
    rrca ;rotate the A button into carr  
    ret c ;we're done here if they're done their swing

UpdatePowerLevel:
    ; otherwise, keep incrementing the power meter
    ld a, [wPowerChargeSpeed]
    ld hl, wPowerMeterLevel
    add [hl] ;add the level and charge speed
    ; store it
    ld [hl], a

    cp METER_SIZE ;is it greater/equal to METER_SIZE or less than 0?
    jr c, .skipAdjust ;if so, adjust it

    ;check if the power meter underflowed of overflowed by checking of the charge speed is positive or negative
    ld a, [wPowerChargeSpeed]
    bit 7, a
    jr nz, .finishStroke;if they didn't even do a swing, they just gain a point

    ;otherwise they've passed max power and the meter should now go down
    cpl 
    inc a ;invert the charge speed
    ld [wPowerChargeSpeed], a



.skipAdjust
 
    ; and then draw it
    call UpdatePowerMeter

    ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a

    jr SwingLoop

.finishStroke ;I'll wrap up whatever here like incrementing the player's score.
    ret

SECTION "swing variables", WRAM0
wPowerChargeSpeed: ;charge speed in px/frame
    db







