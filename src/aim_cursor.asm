INCLUDE "defines.asm"
SECTION "Process Aim Cursor", ROM0

ProcessAimCursor::

    ;read the left and right arrow keys and adjust the aim cursor accordingly
    ldh a, [hPressedKeys]
    ld b, a
    ldh a, [hAimCursorDirection]
    bit PADB_LEFT, b
    jr z, .notLeft
    dec a
.notLeft
    bit PADB_RIGHT, b
    jr z, .notRight
    inc a
.notRight
    ;store the new cursor angle
    ldh [hAimCursorDirection], a
    
    ;now, draw convert that angle to a coordinate pair
    ld l, a
    ld h, HIGH(AimCursorYTable)
    ld b, [hl]
    inc h ;move to the cos table
    ld c, [hl]

    ld hl, wBallY
    ld de, OBJ_CROSSHAIR
    call RenderSprite124OnGreen ;render the cursor relative to the ball

    ld a, SPRITE_CROSSHAIR
    ld [hl+], a ;write the tile number
    ld [hl], 0 ;no special flags
    ret






AIM_CURSOR_DISTANCE equ 35 ;number of pixels from the ball to the aim cursor
    
SECTION "Aim Cursor Sin, Cos Table", ROM0, ALIGN[8]
AimCursorYTable::
FOR I, 256
    db ROUND(MUL(COS(I<<24),AIM_CURSOR_DISTANCE*-1.0))>>16 + BALL_Y_OFFSET 
    ;Y offset from the ball's center to the aim cursor for each angle
ENDR

assert LOW(@) == 0

AimCursorXTable::
FOR I, 256
    db ROUND(MUL(SIN(I<<24),AIM_CURSOR_DISTANCE*1.0))>>16 + BALL_X_OFFSET
    ;X offset from the ball's center to the aim cursor for each angle
ENDR
    



    

SECTION "Aim Cursor HRAM", HRAM

;cursor direction
;uses angles where a circle is 256 degrees
hAimCursorDirection::
    db
