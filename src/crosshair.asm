INCLUDE "defines.asm"
SECTION "Crosshair", ROM0
CROSSHAIR_SPEED equ 2
ProcessCrosshair::
    ld hl, wCrosshairX ;this isn't strictly nescessary, but it optimizes things and hl isn't needed for anything else
	ldh a, [hHeldKeys]
	bit PADB_B, a
	jr nz, DoneMovement ;if B is being pressed, the background will scroll instead, so skip this
    ld b, a

CheckUp:
    bit PADB_UP, b ;check the button
    jr z, .skip
    inc l ;point hl to wCrosshairY
    ld a, [hl]
    sub CROSSHAIR_SPEED ;move the coord if its pressed
    jr nc, .noClamp
    xor a ;clamp to its min/max
.noClamp
    ld [hl-], a ;point it back to wCrosshairX
.skip
    ;and repeat for the other directions

CheckDown:
    bit PADB_DOWN, b 
    jr z, .skip
    inc l
    ld a, [hl]
    add CROSSHAIR_SPEED 
    cp SCRN_Y + 1
    jr c, .noClamp
    ld a, SCRN_Y
.noClamp
    ld [hl-], a
.skip

CheckLeft:
    bit PADB_LEFT, b 
    jr z, .skip
    ld a, [hl]
    sub CROSSHAIR_SPEED
    jr nc, .noClamp
    xor a
.noClamp
    ld [hl], a
.skip

CheckRight:
    bit PADB_RIGHT, b 
    jr z, .skip
    ld a, [hl]
    add CROSSHAIR_SPEED 
    cp SCRN_X + 1
    jr c, .noClamp
    ld a, SCRN_X
.noClamp
    ld [hl], a
.skip
DoneMovement:

SetOAMCrosshair:
    ld a, [hl+] ;X pos
    add 8 - 4 ;oam coord offset - half of size
    ld [wShadowOAM + OBJ_CROSSHAIR + 1], a
    ld a, [hl-] ;Y pos
    add 16 - 4
    ld [wShadowOAM + OBJ_CROSSHAIR], a
CheckDrawing:
    ldh a, [hPressedKeys] ;get the pressed keys instead of the held keys
    assert PADB_A == 0
    rra ;rotate the a button into carry
    ret nc ;jr nc, .done ;draw the crater if a is being pressed
    ldh a, [hSCX] ;add the scroll registers to the crosshair coordinates 
    ;to get the crosshair's position on the golf course
    add [hl] ;X pos
    inc l
    ld b, a
    ldh a, [hSCY]
    add [hl]
    ld c, a
    jp RenderCrater ;tail call
.done
    ret



SECTION "Init Crosshair", ROM0
InitCrosshair::
    ld a, SCRN_X / 2
    ld [wCrosshairX], a
    ld a, SCRN_Y / 2
    ld [wCrosshairY], a
    ld a, SPRITE_CROSSHAIR
    ld [wShadowOAM + OBJ_CROSSHAIR + 2], a
    xor a ;no special flags
    ld [wShadowOAM + OBJ_CROSSHAIR + 3], a
    ret
    

SECTION "Crosshair variables", WRAM0, ALIGN[1] 
;the alignment forces them onto the same page so I can inc/dec l rather than hl
wCrosshairX: db
wCrosshairY: db