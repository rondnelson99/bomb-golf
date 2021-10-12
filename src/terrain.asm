INCLUDE "defines.asm"

SECTION "Look Up Terrain", ROM0
LookUpTerrain:: ;this takes a tilemap-relative X position and tilemap-relative Y position, and returns the type of terrain that pixel represents
    ;Params:
    ;HL: Pointer to 12.4 Y position followed by 12.4 X position

    ld a, [hl+] ;low byte
    ld c, a
    ld a, [hl+] ;high byte
    cp 16 ;make sure it's within the 256 px tilemap range
    jr nc, .terrainOutOfRange
    xor c
    and $0f
    xor c
    swap a
    ld b, a

    ;Now do the X
    ld a, [hl+] ;low byte
    ld c, a
    ld a, [hl+] ;high byte
    cp 16 ;make sure it's within the 256 px tilemap range
    jr nc, .terrainOutOfRange
    xor c
    and $0f
    xor c
    swap a
    ld c, a


   
    ; get Y into L. X is already in A
    ld l, b


    ;convert the coordinate pair in h/a to a tilemap address
    ;thanks calc84maniac


    ld h, HIGH($9800) >> 2
    add hl, hl
    add hl, hl
    rrca
    rrca
    rrca
    xor l
    and %00011111
    xor l
    ld l, a 



    ;and grab that tile number out of VRAM
    wait_vram

    ld l, [hl]

;grab the terrin type from the table
    ld h, HIGH(TerrainList)
    ld a, [hl]
    and a ; if the terrain type is none (zero), we can just call this done
    assert TERRAIN_NONE == 0
    ret z

    ; otherwise, stash the terrain type in e for later
    ld e, a

    ld h, HIGH(TerrainMap) >> 3
    add hl, hl
    add hl, hl
    add hl, hl
    ;now hl points to the start of the terrain map tile

    ld a, b ;get the Y coordinate
    and %00000111 ;mod 8
    or l
    ld l, a 
    ;now hl points to the correct byte, but we just have to read the correct bit of that byte
    ld a, c ;get the X coordinate
    and %00000111 ;mod 8
    ld c, a
    inc c ;increment because we want to rotate it into carry, to evem if X mod 8 is zero, we want to rotate once
    ld a, [hl]
.rotate
    rla 
    dec c
    jr nz, .rotate
    ;now the carry is set if the pixel has the terrain feature
    sbc a ;extend that

    and e ;this is the hazard type for the tile
    ;now the accumulator is 0 for no hazard, but otherwise contains the hazard type
    ret
.terrainOutOfRange ;when the ball is outside the course area
    ld a, TERRAIN_OOB
    ret











TERRAIN_NONE equ 0
TERRAIN_GREEN equ 1
TERRAIN_OOB equ 2
TERRAIN_WATER equ 3
TERRAIN_BUNKER equ 4
export TERRAIN_NONE, TERRAIN_GREEN, TERRAIN_OOB, TERRAIN_WATER, TERRAIN_BUNKER

SECTION "terrain list", ROM0, ALIGN[8, $80] ;start at $80 since that's where the course tiles start
TerrainList:
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER

    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER

    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_GREEN
    db TERRAIN_GREEN
    db TERRAIN_GREEN
    db TERRAIN_GREEN
    db TERRAIN_GREEN
    db TERRAIN_OOB
    db TERRAIN_BUNKER
    db TERRAIN_BUNKER

    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_WATER
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_OOB
    db TERRAIN_NONE
    db TERRAIN_GREEN
    db TERRAIN_GREEN
    db TERRAIN_GREEN
    db TERRAIN_GREEN

    assert SIZEOF("terrain list") == 60 ;there are 60 tiles in the tileset

SECTION "terrain map", ROM0, ALIGN[11, $80 * 8]

TerrainMap: ;this is 1bpp representation of the golf course tiles where each tile has a special feature (bunker, OOB, water, etc), and a 1 means it has that feature, but a zero means it does not 
    INCBIN "res/courseterrain.1bpp"



