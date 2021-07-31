INCLUDE "defines.asm"
SECTION "Crosshair", ROM0
CROSSHAIR_SPEED equ 2
ProcessCrosshair::
	ldh a, [hHeldKeys]
	bit PADB_B, a
	jr nz, SetOAMCrosshair ;if B is being pressed, the background will scroll instead, so skip this
    ld b, a

CheckUp:
    bit PADB_UP, b ;check the button
    jr z, .skip
    ld a, [wCrosshairY]
    sub CROSSHAIR_SPEED ;move the coord if its pressed
    jr nc, .noClamp
    xor a ;clamp to its min/max
.noClamp
    ld [wCrosshairY], a
.skip
    ;and repeat for the other directions

CheckDown:
    bit PADB_DOWN, b 
    jr z, .skip
    ld a, [wCrosshairY]
    add CROSSHAIR_SPEED 
    cp SCRN_Y + 1
    jr c, .noClamp
    ld a, SCRN_Y
.noClamp
    ld [wCrosshairY], a
.skip

CheckLeft:
    bit PADB_LEFT, b 
    jr z, .skip
    ld a, [wCrosshairX]
    sub CROSSHAIR_SPEED
    jr nc, .noClamp
    xor a
.noClamp
    ld [wCrosshairX], a
.skip

CheckRight:
    bit PADB_RIGHT, b 
    jr z, .skip
    ld a, [wCrosshairX]
    add CROSSHAIR_SPEED 
    cp SCRN_X + 1
    jr c, .noClamp
    ld a, SCRN_X
.noClamp
    ld [wCrosshairX], a
.skip

SetOAMCrosshair:
    ld a, [wCrosshairX]
    add 8 - 4 ;oam coord offset - half of size
    ld [wShadowOAM + OBJ_CROSSHAIR + 1], a
    ld a, [wCrosshairY]
    add 16 - 4
    ld [wShadowOAM + OBJ_CROSSHAIR], a
    
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
    

SECTION "Crosshair variables", WRAM0
wCrosshairX: db
wCrosshairY: db