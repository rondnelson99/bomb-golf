INCLUDE "defines.asm"

AUTO_REPEAT_DELAY equ 20 ; minimum number of frames to hold a button down for before it starts repeating
AUTO_REPEAT_INTERVAL_MASK equ %0 ; when frames held ANDed this is zero, process a new input
AIM_CURSOR_DISTANCE equ 35 ;number of pixels from the ball to the aim cursor
AIM_CURSOR_PRESCALER equ 2 ; The cursor direction is also used for physics. 
SECTION "Process Aim Cursor", ROM0

ProcessAimCursor::

    ;read the left and right arrow keys and adjust the aim cursor accordingly
    ld hl, hAimCursorDirection
    ;the cursois moves once when a key is pressed, and then again every few frames after the ket is held down for a while
    ldh a, [hPressedKeys]
    ld b, a
    bit PADB_LEFT, b ; check if the left arrow key is pressed this frame
    jr nz, .moveLeft
    ; now, check if left has been held for longer than a threshold
    ldh a, [hFramesHeldLeft]
    cp AUTO_REPEAT_DELAY
    jr c, .notLeft
    ;if so, check if it's time to move again
    and AUTO_REPEAT_INTERVAL_MASK
    jr nz, .notLeft

.moveLeft    
    dec [hl]

.notLeft
    bit PADB_RIGHT, b
    jr nz, .moveRight
    ldh a, [hFramesHeldRight]
    cp AUTO_REPEAT_DELAY
    jr c, .notRight
    and AUTO_REPEAT_INTERVAL_MASK
    jr nz, .notRight

.moveRight
    inc [hl]
.notRight
    assert AIM_CURSOR_PRESCALER == 2
    ;now, draw convert that angle to a coordinate pair
    ld l, [hl]
    ld h, HIGH(AimCursorYTable)
    ld a, [hl]
    sra a
    add BALL_Y_OFFSET
    ld b, a

    inc h ;move to the cos table
    ld a, [hl]
    sra a
    add BALL_X_OFFSET
    ld c, a


    ld hl, wBallY
    ld de, OBJ_CROSSHAIR
    call RenderSprite124OnGreen ;render the cursor relative to the ball

    ld a, SPRITE_CROSSHAIR
    ld [hl+], a ;write the tile number
    ld [hl], 0 ;no special flags
    ret







;We use a larger magnitude in the table, and then shift to get the smaller offset for visuals
SECTION "Aim Cursor Sin, Cos Table", ROM0, ALIGN[8]
AimCursorYTable::
FOR I, 0, 1.0, 1.0/256
    db ROUND(MUL(COS(I),AIM_CURSOR_DISTANCE*-1.0*AIM_CURSOR_PRESCALER))>>16 
    ;Y offset from the ball's center to the aim cursor for each angle
ENDR

assert LOW(@) == 0

AimCursorXTable::
FOR I, 0, 1.0, 1.0/256
    db ROUND(MUL(SIN(I),AIM_CURSOR_DISTANCE*1.0*AIM_CURSOR_PRESCALER))>>16
    ;X offset from the ball's center to the aim cursor for each angle
ENDR
    



    

SECTION "Aim Cursor HRAM", HRAM

;cursor direction
;uses angles where a circle is 256 degrees
hAimCursorDirection::
    db
