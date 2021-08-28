INCLUDE "defines.asm"

ARROW_DIRECTION_INIT equ $FF ;an arrow direction of $ff indicates that the direction needs to be initialized

SECTION "Init Aim Arrow", ROM0
InitAimArrow::
    ld hl, wArrowFacingDirection
    xor a
    ld [hl+], a ;facing up
    ld [hl], ARROW_DIRECTION_INIT
    ret

SECTION "Check Aiming", ROM0
CheckAiming:: ;reads player input and adjusts the aiming direction if nescessary
    ldh a, [hHeldKeys]
    bit PADB_B, a 
    jr nz, UpdateAimArrow ;if they're holding B, then the camera moves instead
    
    ldh a, [hPressedKeys]
    ld b, a
    ld hl, wArrowFacingDirection

    bit PADB_LEFT, b
    jr z, .notLeft
.left
    ld a, [hl]
    dec a ;move counterclockwise one direction
    and $0f ;mod 16
    ld [hl], a
    jr UpdateAimArrow ;they can't press left and right at the same time, so we're done here

.notLeft
    bit PADB_RIGHT, b
    jr z, .notRight
.right
    ld a, [hl]
    inc a ;move clockwise one direction
    and $0f ;mod 16
    ld [hl], a

.notRight


UpdateAimArrow:: ;draws an arrow from the golf ball in whatever ditection it's facing
    ;check if the tile in VRAM needs updating
    ld hl, wArrowFacingDirection
    ld a, [hl+]
    cp [hl] ;is the current direction equal to the old direction?
    jr z, .doneUpdateTile
.updateTile ;if not, replce the arrow tile in VRAM
    ; a contains the desired arrow facing direction
    ld [hl], a ; we're updating it, wo set wOldArrowDirection to the new one
    swap a ; multiply by 16 to get the offset within the tile area
    ld e, a ;low byte of the tile data pointer
    ld d, HIGH(ArrowTiles)
    assert LOW(ArrowTiles) == 0
    ; de now pints to the desired tile
    ld hl, $8000 + SPRITE_ARROW * 16 ;pointer to the arrow location in VRAM
    ld c, 16 ;copy 1 tile
    call LCDMemcpySmall ;write the tile

.doneUpdateTile

    ld hl, wBallY ;this is a 12.4 course-relative coordinate folloewd by the X coordinate
    ld a, [hl+]
    ld b, a
    ld a, [hl+] ;grab the Y coord

    xor b
    and $0F
    xor b 
    swap a;convert to integer

    ld c, a

    ld a, [hl+]
    ld b, [hl] ;grab the x coord

    xor b
    and $F0
    xor b 
    swap a ;convert to integer

    ld b, a

    ;now integer ball Y is in c, X in b

    ld a, [wArrowFacingDirection]
    add a, a ;double it bc there are two bytes per entry
    ld l, a
    ld h, HIGH(ArrowPositionLUT)
    assert LOW(ArrowPositionLUT) == 0

    ;now hl points to the the Y offset of the arrow, followed by X offset

    ldh a, [hSCY] 
    cpl
    inc a
    add [hl]
    add c
    ; a contains Ball coord + arrow offset - camera position. If it's a valid position, then it's ready to go in OAM

    cp STATUS_BAR_HEIGHT - 8 + OAM_Y_OFS;if the sprite is fully hidden by the status bar, don't draw it
    jr c, .hide
    
    ld c, a

    inc l ;the table is aligned so this won't overflow

    ldh a, [hSCX] ;do the same for the X coord
    cpl 
    inc a
    add [hl]
    add b

    ;now write to OAM
    ld hl, OBJ_ARROW
    ld [hl], c ;write the Y coord
    inc l ;this is fine bc OAM is aligned
    ld [hl+], a
    ld a, SPRITE_ARROW ;tile number
    ld [hl+], a
    ld [hl], 0 ;no special flags

    ret


.hide
    xor a ;zero the Y coordinate in OAM to hide it
    ld [OBJ_ARROW + OAMA_Y], a
    ret

MACRO ArrowPosition ;arguments are relative to the center of the arrow
    db \1 - 4 + OAM_Y_OFS
    db \2 - 4 + OAM_X_OFS
ENDM

SECTION "Arrow Position Table", ROM0, ALIGN[8]
ArrowPositionLUT: ;table of Y and X offsets relative to the ball for each direction, plus the OAM offset
    ArrowPosition -8, 0 ;up
    ArrowPosition -8, 3
    ArrowPosition -7, 5 
    ArrowPosition -3, 8 
    ArrowPosition 0,  8 ;right
    ArrowPosition 3,  8 
    ArrowPosition 5, 5 
    ArrowPosition 7, 4 
    ArrowPosition 8, 0 ;down
    ArrowPosition 8, -3 
    ArrowPosition 6, -6 
    ArrowPosition 3, -8 
    ArrowPosition 0, -8 ;left
    ArrowPosition -3, -8 
    ArrowPosition -6, -6 
    ArrowPosition -8, -4 

SECTION "Arrow Tiles", ROM0, ALIGN[8] ; the data is 256 bytes so alignment should be basically free
ArrowTiles:
    INCBIN "res/arrows.2bpp" ;16 tiles, one for each direction 0 (straight up) clockwse to 15 (upwards angled left)


SECTION "Arrow Variables", WRAM0
wArrowFacingDirection:: ; This can be written to by other parts of the code to change the direction that the arrow is facing
    db ;stores a direction from 0 (straight up) clockwse to 15 (upwards angled left)
wOldArrowDirection: ;this is used to ckeck if the direction has changed (and a new tile needs to be copied into VRAM)
    db ;$FF indicates that the direction needs to be initialized