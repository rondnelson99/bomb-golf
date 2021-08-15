INCLUDE "defines.asm"
SECTION "render crater", ROM0

CRATER_WIDTH equ 48
CRATER_HEIGHT equ 48


;function to software-render a crater at the desired coordinates
;takes B as X coord and C as Y coord of center

;so basically the idea here is that we store the crater graphic and a mask for transparency in a buffer.
;we use that buffer to rotate bits and get the horizontal position right
;then we take the graphics that the crater displays over out of VRAM, and mask them off
;we combine them with the crater graphics, and then copy those into VRAM, keeping in mind the vertical offset.
RenderCrater::
    ;adjust the coordinates to get the top-left corner rather than the center
    ld a, b
    sub CRATER_WIDTH / 2
    ld b, a
    ld a, c
    sub CRATER_HEIGHT / 2
    ld c, a

    push bc ;save the coordinates for later

        ;init a couple pointers
        ld hl, wCraterMaskPointer
        ld a, LOW(wCraterMaskBuffer)
        ld [hl+], a
        ld a, HIGH(wCraterMaskBuffer)
        ld [hl+], a ; now hl points to wCraterTilePointer
        ld a, LOW(wCraterBuffer)
        ld [hl+], a
        ld [hl], HIGH(wCraterBuffer)

    UnpackGraphics: ;unpack the crater graphic as well as the crater mask graphic
        ;unpack the crater graphic
        ld de, PB16Crater
        ld hl, wCraterBuffer
        ld b, SIZEOF("Crater Buffer") / 16
        call pb16_unpack_block

        ld l, e ;transfer de to hl because it already contains a pointer to PB8CraterMask
        ld h, d
        ld de, wCraterMaskBuffer
        ld b, SIZEOF("Crater Mask Buffer") / 8
        call UnPB8

Rotate:
.calculateHorizontalOffset
    pop bc ; b contains the horizontal position
    push bc ; but we still need to save these for later
        ld a, b
        and %00000111 ; X position mod 8
        sub 4 ; this decides how much we need to rotate. 
        ;-4 indicates rotating left 4 px, 0 indicates that we're perfectly aligned, and 3 indicates rotating right 3 px
        ld b, a ;both codepaths store this in b
        jr c, .rotateLeft
        jr z, .doneRotate ;yay early exit!
    .rotateRight
        ld hl, wCraterBuffer
        ld c, CRATER_HEIGHT * 2 ; how many rows of pixels to rotate
        call CraterRotateRight ;this preserves b
        ld hl, wCraterMaskBuffer ;rotate the mask too
        ld c, CRATER_HEIGHT
        call CraterRotateRight
        jr .doneRotate

    .rotateLeft
        ld c, - CRATER_HEIGHT * 2 ; how many rows of pixels to rotate
        ;make it negative so that we can add it to hl to move left one byte
        ld hl, wCraterBuffer + CRATER_HEIGHT * 2 * (CRATER_WIDTH) / 8 ;this points to the top-right byte of wCraterBuffer
        call CraterRotateLeft
        ld hl, wCraterMaskBuffer + CRATER_HEIGHT * (CRATER_WIDTH) / 8 ;top-right byte of the mask this time. No *2 because this is 1bpp instead of 2bpp
        ld c, - CRATER_HEIGHT
        call CraterRotateLeft

        ;fall through
        
    .doneRotate


    pop hl ; get the coordinates
    push hl ;but still save them

        ld a, l ;grab the Y coordinate
        and %00000111 ;mod 8
        ld [wCraterTopOffset], a ;this is the space at the top of the tiles


        ;convert the coordinate pair in hl to a tilemap address
        ;thanks calc84maniac

        ; H=X, L=Y
        ld a, h
        ld h, HIGH($9800) >> 2
        add hl, hl
        add hl, hl
        rrca
        rrca
        rrca
        xor l
        and %00011111
        xor l
        ld l, a ;13 bytes, 15 cycles

        ld c, 7 ;this is a counter for the columns we've rendered
        push hl ;this gets pushed twice. Once for the rendering process and then again for the tilemap updating process

        RenderCraterColumn:
            push hl ;save these
                
                push bc

                    ld de, SCRN_VX_B ;32 byte displacement between rows in the tilemap

                    ;copy 7 tilemap entries vertically
                    wait_vram

                    ld a, [hl] ;get three bytes
                    add hl, de
                    res 2, h ;we have to to this after every add to make hl wrap around to the top instead of spilling into the $9C00 tilemap
                    ld b, [hl]
                    add hl, de
                    res 2, h
                    ld c, [hl] ;14 of 15 cycles used
                    add hl, de 
                    res 2, h

                    ld [wCraterTilemapStrip], a ;store them
                    ld a, b
                    ld [wCraterTilemapStrip + 1], a
                    ld a, c
                    ld [wCraterTilemapStrip + 2], a

                   
                    wait_vram
                 
                    ld a, [hl] ;get 3 more bytes
                    add hl, de
                    res 2, h
                    ld b, [hl]
                    add hl, de
                    res 2, h
                    ld c, [hl] ;14 of 15 cycles used
                    add hl, de
                    res 2, h

                    ld [wCraterTilemapStrip + 3], a

                    wait_vram
                    ld a, [hl] ;get the last byte
                    ld [wCraterTilemapStrip + 6], a ;store it so we can clobber a

                    ;now we can clobber hl
                    ld hl, wCraterTilemapStrip + 4 ;store the third-last and second-last bytes
                    ld a, b
                    ld [hl+], a
                    ld [hl], c

                CopyFirstTile:
                    ld a, [wCraterTilemapStrip] 
                    call CopyTileFromVRAM


                    ;grab the pointers to the graphic and mask buffers
                    ld hl, wCraterMaskPointer
                    ld a, [hl+]
                    ld c, a
                    ld a, [hl+]
                    ld b, a ;put it in bc
                    ;next in ram is wCraterTilePointer
                    ld a, [hl+]
                    ld e, a
                    ld d, [hl]

                    ;get the vertical offset
                    ld a, [wCraterTopOffset]
                    add a, a ;this is doubled since we have two bytes per row of pixels
                    add LOW(wCraterTileBuffer)
                    ld l, a ;I don't have to worry about carry because this is page-aligned
                    ld h, HIGH(wCraterTileBuffer) ;ld hl, wCraterTileBuffer + wCraterTopOffset


                    ;now actually do all the masking for the software rendering
                    call RenderCraterMaskLoop
                    
                    call PushslideTileToVRAM
                    
                    ld hl, wCraterTilemapStrip + 1
                    call RenderCraterTile
                    call RenderCraterTile
                    call RenderCraterTile
                    call RenderCraterTile
                    call RenderCraterTile   ;render a full column of tiles
                    ;the last tile is special because there's a margin at the bottom that we need to skip masking for
                    ld a, [hl+] ;this is the last byte of the vertical tilemap strip
                    call CopyTileFromVRAM ;copy the tile like usual
                    ;now we need a special loop for the masking that won't chew through the whole tile
                    ;uses a pushed loop counter instead
                    ld a, [wCraterTopOffset]
                    and a ;if this is zero, then we don't need to do any masking here, and pointers will get borked if we do, so skip this
                    jr z, RenderCraterFinalMaskLoop.end
                    push af
                        ;this is otherwise the same as RenderCraterMaskLoop
                        ;fetch the tile and mask pointers
                        ld hl, wCraterMaskPointer
                        ld a, [hl+]
                        ld c, a
                        ld a, [hl+]
                        ld b, a ;put it in bc
                        ;next in ram is wCraterTilePointer
                        ld a, [hl+]
                        ld e, a
                        ld d, [hl]

                        ld hl, wCraterTileBuffer
                    RenderCraterFinalMaskLoop:
                        ld a, [bc] ;grab the mask byte
                        cpl ;invert it. I can't invert the source graphic instead because zeros may have been shifted into the sides of it using sla/srl
                        and [hl] ;mask the tile byte
                        ld [hl], a ;store it
                        ld a, [de] ;grab the crater graphic
                        or [hl] ;add it to the tile
                        ld [hl+], a ;store the finished tile byte
                        inc de ; move to the next tile byte and crater graphic byte, but reuse the same mask byte
                        ;do it again
                        ld a, [bc]
                        cpl
                        and [hl]
                        ld [hl], a
                        ld a, [de]
                        or [hl]
                        ld [hl+], a
                        inc bc ; increment both pointers this time
                        inc de

                    pop af
                    dec a ;check if we've just done the last pixel
                    push af

                        jr nz, RenderCraterFinalMaskLoop      

                    pop af

                
                        ;store the pointers

                    ld hl, wCraterMaskPointer
                    ld a, c
                    ld [hl+], a
                    ld a, b
                    ld [hl+], a
                    ld a, e
                    ld [hl+], a
                    ld [hl], d
                .end
                    call PushslideTileToVRAM
                    
                pop bc ;this is the counter of rows we've rendered
            pop hl ;and this is the pointer to the tilemap
            ;move to the next column by incrementing only the lower 5 bis of l
            
            ld a, l
            inc a
            xor l
            and %00011111 ;masked merge
            xor l
            ld l, a

            dec c
            jp nz , RenderCraterColumn ;this is a little too long for jr

        UpdateTilemap: ; this is a very LUT-heavy approach. 
            ;It would be kind of a pain to adapt to other crater sizes
            ;first we pick one of 4 pre-baked tilemaps to copy in
            ;how do we figure out which one? we take the stack pointer that we use to pushslide the tiles in.
            ;it can only have one of four values
        LoadTilemapPointer:
            ld a, [wCraterVRAMSP]
            ld d, HIGH(CraterTilemaps)
            cp $F0 ; this indicates that we're drawing the first crater
            jr z, .tilemap1
            cp $E0
            jr z, .tilemap2
            cp $D0
            jr z, .tilemap3
        .tilemap4
            ld e, LOW(CraterTilemap4)
            jr .done
        .tilemap1
            ld e, LOW(CraterTilemap1)
            jr .done
        .tilemap2
            ld e, LOW(CraterTilemap2)
            jr .done
        .tilemap3
            ld e, LOW(CraterTilemap3)
        .done

        pop hl ;this is the tilemap address of the top-left corner.
    pop bc ; and this is Y coord in B, X coord in c

    ;so now we copy the tilemap snippet in [de] to the tilemap area at [hl].
    ;easy, right? But there's a catch. 
    ;We have to clip it at the sides to avoid the graphics leaking around the edges of the tilemap.
    ;we start with the top, and the Y coordinate we just popped can help with that.
    ;we don't care about the X coordinate though, so we can use that for our row counter.
CraterCopyTilemap:
    ld b, CRATER_HEIGHT / 8 + 1 ; ;this is the counter of rows

    ld a, c
    cp - CRATER_HEIGHT / 2 ;if this doesn't carry, then the middle of the crater is at the top of the screen, but we're pointing to the bottom of the screen now, so we should keep going until we get to the top
    jr c, .doneVerticalAdjust
.verticalAdjustLoop
    ;decrement the row counter
    dec b
    ;add  a displacement to de to point to the next row
    ld a, CRATER_WIDTH / 8 + 1
    add e
    ld e, a
    adc d
    sub e
    ld d, a

    ;add a displacement to hl to point to the next row
    ld a, SCRN_VX_B ;one tilemap row
    add l
    ld l, a
    adc h
    sub l
    ld h, a

    bit 2, h ; if this is set, we've reached the end of the $9800 tilemap and start drawing from the top
    res 2, h ; this will force the add to wrap around back to the start of the tilemap instead of moving to the $9C00 tilemap
    ;res doesn't affect flags, so we can use the z flag to check if we're done
    jr z, .verticalAdjustLoop

.doneVerticalAdjust
.rowloop
    ld c, CRATER_WIDTH / 8 + 1 ;byte counter
; check if we need to horizontally adjust too
    ld a, l ;low byte of tilemap address
    and %00011111 ;get just the X portion
    cp SCRN_VX_B - CRATER_WIDTH / 8 / 2 ; if this doesn't carry, then we're at the end of the line and need to wait until we wrap around to the start
    jr nc, .horizontalFrontPorch
    cp SCRN_VX_B - CRATER_WIDTH / 8 + 1 ; if this doesn't carry, then we're approaching the end of the line but still on the right side of it, so loop until the end of the line.
    jr nc, .byteLoopUntilBackPorch
    jr .byteLoop ;if the address passed both of those checks, then we can just copy a whole row
.horizontalFrontPorch ;blank the left edge of the crater
    dec c ;dec the byte counter because we're skipping a byte
    inc de ;skip a tilemap entry too
    ;a stores the low 5 bits of hl, so increment and mask
    inc a
    and %00011111 
    jr nz, .horizontalFrontPorch
.finishHorizontalAdjust
    ld a, l ;reset the lower bits of l since we're at the start of a line
    and %11100000 
    ld l, a
.doneHorizontalAdjust
.byteloopAfterFrontPorch ;this loop only copies until c is depleted and we reach the end of the crater. It doesn't check for the end of the screen
    wait_vram
    ld a, [de]
    inc de
    ld [hl+], a
    ;keep writing until b runs out
    dec c
    jr z, .finishRow ;this loop is wierdly unrolled in order to minimize VRAM checks
    ld a, [de]
    ld [hl+], a ;uses 13 of 16 VRAM cycles
    inc de
    dec c
    jr nz, .byteloopAfterFrontPorch

    ld a, l
    add SCRN_VX_B + SCRN_VX_B - (CRATER_WIDTH / 8 + 1) ;add an extra row because of the way it wraps around at the start of this codepath
    ld l, a
    adc h
    sub l
    ld h, a
    jr .finishRowDoneAdd

.byteLoop;this loop only copies until c is depleted and we reach the end of the crater. It doesn't check for the end of the screen
    wait_vram
    ld a, [de]
    inc de
    ld [hl+], a
    ;keep writing until b runs out
    dec c
    jr z, .finishRow ;this loop is wierdly unrolled in order to minimize VRAM checks
    ld a, [de]
    ld [hl+], a ;uses 13 of 16 VRAM cycles
    inc de
    dec c
    jr nz, .byteLoop
    jr .finishRow

.byteLoopUntilBackPorch ;this loop only copies until we reach the horizontal end of the tilemap
    wait_vram
    ld a, [de]
    inc de
    ld [hl+], a
    dec c ;decrement c for the back porch, but don't check if its zero
    ld a, l 
    and %00011111 ;if tilemap address mod 32 is 0, then we're at the start of a tilemap
    jr z, .horizontalBackPorch
    ld a, [de]
    ld [hl+], a ;uses 16 of 16 VRAM cycles
    inc de
    dec c
    ld a, l
    and %00011111
    jr nz, .byteLoopUntilBackPorch
.horizontalBackPorch ;discard the remaining bytes in the row by incrementing the pointers until c is 0 (indicating the end of a crater row)
    inc de ;crater tilemap pointer
    inc l ;tilemap pointer. This won't overflow since we just waited for l % 32 == 0
    dec c
    jr nz, .horizontalBackPorch

.finishRow ;add a displacement to hl to move to the start of the next line
    ld a, l
    add SCRN_VX_B - (CRATER_WIDTH / 8 + 1)
    ld l, a
    adc h
    sub l
    ld h, a

.finishRowDoneAdd
    ;now check if we just passed the end of the $9800 tilemap, if so, exit to avoid wrapping arounf to the top.
    bit 2, h
    ret nz

    dec b ;move to the next row
    jr nz, .rowloop
    
    ret ;finally 







    



SECTION "Render Crater Tile", ROM0
RenderCraterTile:
    ld a, [hl+] ;grab a tile from the vertical strip
    push hl ;we will make sure and return this in hl
        call CopyTileFromVRAM ;this will fill wCraterTileBuffer with that tile
        call RenderCraterPointerAndMask ;and this will do all the masking to give us a nice, software rendered tile
        call PushslideTileToVRAM
    pop hl
    ret



    
SECTION "Copy Crater TIle From VRAM", ROM0
CopyTileFromVRAM:
    swap a ;convert a tilemap entry to a tile address in the $8800 area
    ld h, a
    and $F0
    ld l, a
    xor h
    or HIGH($8800) & $F0
    ld h, a
    bit 3, h
    jr nz, .skipAdjustFor9000
    set 4, h
.skipAdjustFor9000 ;if the tile index is below $80, we need to set bit 4 of h to get the tile from $9000 rather than $8000


    ;now we need to copy that tile into wCraterTileBuffer
    ;this takes 3 scanlines probably
    ld [wStoredSP], sp
    di ;can't have this getting interruption while the stack is wack
    ld sp, hl
    ld hl, wCraterTileBuffer

    wait_vram
    pop bc
    pop de
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a
    pop bc ;15 of 15 VRAM cycles used
    ld a, e
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a ;6 bytes copied so far  

    wait_vram ;exact same pattern again
    pop bc
    pop de
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a
    pop bc ;15 of 15 VRAM cycles used
    ld a, e
    ld [hl+], a
    ld a, d
    ld [hl+], a
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a ;12 bytes copied so far  

    wait_vram ;now we only need 4 more bytes

    pop bc
    pop de ;6 of 15 VRAM cycles used
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ld [hl], d ;that's the full 16 bytes

    ld sp, wStoredSP
    pop hl
    ld sp, hl ;restore the stack pointer
    reti ; ei/ret

SECTION "Pushslide Tile to VRAM", ROM0
PushslideTileToVRAM:
    ;now we pushslide our new tile into VRAM

    ld [wStoredSP], sp ;save the main sp
    di ;can't have this getting interrupted while the stack is wack
    ld sp, wCraterVRAMSP
    pop hl
    ld sp, hl ;get our sp that points to VRAM

    ld hl, wCraterTileBufferEnd - 1 ; point hl to the last tile
    ld a, [hl-]
    ld d, a
    ld a, [hl-]
    ld e, a
    ld a, [hl-]
    ld b, a
    ld a, [hl-]
    ld c, a ;cue up 4 bytes

    wait_vram

    push de
    push bc
    ld a, [hl-]
    push af ;uses 14 of 16 VRAM cycles
    inc sp ;the flags we just pushed are garbage. If we inc sp, they'll be overwritten by the next push
    ;we've written 5 of 16 bytes now

    ld a, [hl-]
    ld d, a
    ld a, [hl-]
    ld e, a
    ld a, [hl-]
    ld b, a
    ld a, [hl-]
    ld c, a ;cue up 4 bytes

    wait_vram

    push de
    push bc
    ld a, [hl-]
    push af ;uses 14 of 16 VRAM cycles
    inc sp
    ;we've written 10 of 16 bytes now
    
    ld a, [hl-]
    ld d, a
    ld a, [hl-]
    ld e, a
    ld a, [hl-]
    ld b, a
    ld a, [hl-]
    ld c, a 
    ld a, [hl-]
    ld l, [hl]
    ld h, a ;cue up 6 bytes this time, destroying hl

    wait_vram

    push de
    push bc
    push hl ;uses 12 of 16 VRAM cycles

    ;save this sp for later
    ld [wCraterVRAMSP], sp

    ld sp, wStoredSP ;and restore the main stack
    pop hl
    ld sp, hl
    reti ;ei/ret

SECTION "Render Crater Mask Loop", ROM0
RenderCraterPointerAndMask:
    ;fetch the tile and mask pointers
    ld hl, wCraterMaskPointer
    ld a, [hl+]
    ld c, a
    ld a, [hl+]
    ld b, a ;put it in bc
    ;next in ram is wCraterTilePointer
    ld a, [hl+]
    ld e, a
    ld d, [hl]

    ld hl, wCraterTileBuffer

RenderCraterMaskLoop:
    ld a, [bc] ;grab the mask byte
    cpl ;invert it. I can't invert the source graphic instead because zeros may have been shifted into the sides of it using sla/srl
    and [hl] ;mask the tile byte
    ld [hl], a ;store it
    ld a, [de] ;grab the crater graphic
    or [hl] ;add it to the tile
    ld [hl+], a ;store the finished tile byte
    inc de ; move to the next tile byte and crater graphic byte, but reuse the same mask byte
    ;do it again
    ld a, [bc]
    cpl
    and [hl]
    ld [hl], a
    ld a, [de]
    or [hl]
    ld [hl], a
    inc bc ; increment both pointers this time
    inc de
    inc l ;this will be zero at the end of the buffer
    jr nz, RenderCraterMaskLoop

    ;store the pointers
    ld hl, wCraterMaskPointer
    ld a, c
    ld [hl+], a
    ld a, b
    ld [hl+], a
    ld a, e
    ld [hl+], a
    ld [hl], d

    ret

    

 
SECTION "Crater Tilemap Strip", WRAM0
wCraterTilemapStrip:
    ds (CRATER_HEIGHT + 8) / 8

SECTION "Crater Tile Buffer", WRAM0 ;a buffer for a single tile being actively drawn
wCraterTileBuffer:
    ds 16
    align 8 ;this way we can inc l and use the z flag to see if we reached the end of the buffer
wCraterTileBufferEnd:

SECTION "Crater Misc Variabes", wram0
wCraterVRAMSP:: ;permanently stored sp for VRAM pushslides
    ds 2
wCraterTopOffset: ;number of extra pixels between the tile boundary and the crater top
    ds 1
wCraterMaskPointer: ; a pointer into the Crater Mask Buffer that will be used for the tile masking
    ds 2
wCraterTilePointer: ; a pointer to the crater graphics data used for the same purpose
    ds 2










SECTION "Crater Rotate Right", ROM0
/*
Params:
HL: pointer to the buffer that we're rotating
C: column size / displacement between columns
B: Number of bits to rotate right

Register Map:
A: bits going in and out of memory (only the top bit is used)
B: holds the number of bits to rotate. 
DE: displacement to add to hl whenever we need to move rightwards to the next byte
HL: points to the memory area being rotated
*/
CraterRotateRight:
    ld d, 0 ;this remains zero for the entire subroutine
    ld e, c ; get the column displacement into de
.row
    push bc ;push the number of rows to rotate (in c) and the number of bits to rotate (in b)   
  
.rowBit
    push hl ;push the pointer to the start of the row

    srl [hl] ;first byte
    sbc a ;extend carry into a
    add hl, de ;move to the next bit
    
    rra ;restore carry from the previous memory rotate
    rr [hl] ;second byte
    sbc a
    add hl, de

    rra 
    rr [hl] ;third byte
    sbc a
    add hl, de

    rra 
    rr [hl] ;fourth byte
    sbc a
    add hl, de

    rra 
    rr [hl] ;fifth byte
    sbc a
    add hl, de

    rra 
    rr [hl] ;sixth byte
    sbc a
    add hl, de

    rra 
    rr [hl] ;seventh byte

    pop hl;grab the start of the line from the stack, but still leave it there for next time with a push at the start of the loop

    dec b ;loop until we've rotated enough bits
    jr nz, .rowBit

    pop bc ; pop the number of rows to rotate (in c) and the number of bits to rotate (in b) 
    inc hl; the next row starts one byte later
    dec c ;advance to the next row
    jr nz, .row

    ret


SECTION "Crater Rotate Left", ROM0
/*
Params:
HL: pointer to the buffer that we're rotating. Starts at the top-right
C: negative column size / displacement between columns
B: negative Number of bits to rotate right

Register Map:
A: bits going in and out of memory (only the top bit is used)
B: holds the number of bits to rotate. 
DE: displacement to add to hl whenever we need to move leftwards to the next byte
HL: points to the memory area being rotated
*/
CraterRotateLeft:
    ld d, $FF ;e is negative and I want to add it to hl, so d needs to be $ff. This remains constant for the duration of the subroutine.
    ld e, c ; get the column displacement into de
.row
    push bc ;push the number of rows to rotate (in c) and the number of bits to rotate (in b)   
    
.rowBit
    push hl ;push the pointer to the start of the row

    sla [hl] ;first byte
    sbc a ;extend carry into a
    add hl, de ;move to the next bit
    
    rla ;restore carry from the previous memory rotate
    rl [hl] ;second byte
    sbc a
    add hl, de

    rla
    rl [hl] ;third byte
    sbc a
    add hl, de

    rla 
    rl [hl] ;fourth byte
    sbc a
    add hl, de

    rla 
    rl [hl] ;fifth byte
    sbc a
    add hl, de

    rla 
    rl [hl] ;sixth byte
    sbc a
    add hl, de

    rla 
    rl [hl] ;seventh byte

    pop hl;grab the start of the line from the stack, but still leave it there for next time with a push at the start of the loop

    inc b ;loop until we've rotated enough bits. inc because the counter is negative
    jr nz, .rowBit

    pop bc ; pop the number of rows to rotate (in c) and the number of bits to rotate (in b) 
    inc hl; the next row starts one byte later
    inc c ;advance to the next row. inc because the counter is negative
    jr nz, .row

    ret








SECTION "Crater Graphics", ROM0
PB16Crater:
INCBIN "res/crater.v2bpp.pb16"
PB8CraterMask:
INCBIN "res/cratermask.v1bpp.pb8"

SECTION "Crater Buffer", WRAM0
wCraterBuffer:
    ds CRATER_HEIGHT * 2 * ((CRATER_WIDTH + 8) / 8) ; times 2 because 2 bytes = 1 row of pixels. 
    ;Add an extra 8 px so we have room to rotate left and right

SECTION "Crater Mask Buffer", WRAM0
wCraterMaskBuffer:
    ds CRATER_HEIGHT * ((CRATER_WIDTH + 8) / 8) ;this time only 1 byte = 1 row of pixels

SECTION "Crater Tilemaps", ROM0, ALIGN[8] ;these tilemaps will be pasted into the main tilemap where the crater should go
;they should all be on the same page so they can share a high byte
CraterTilemaps:
CraterTilemap1: 
    FOR Y, CRATER_HEIGHT / 8 + 1
        FOR X, CRATER_WIDTH / 8 + 1
            db $7F - Y - X * 7
        ENDR
    ENDR
CraterTilemap2:
    FOR Y, CRATER_HEIGHT / 8 + 1
        FOR X, CRATER_WIDTH / 8 + 1
            db $4E - Y - X * 7
        ENDR
    ENDR

CraterTilemap3:
    FOR Y, CRATER_HEIGHT / 8 + 1
        FOR X, CRATER_WIDTH / 8 + 1
            db $1D - Y - X * 7
        ENDR
    ENDR

CraterTilemap4:
FOR Y, CRATER_HEIGHT / 8 + 1
    FOR X, CRATER_WIDTH / 8 + 1
        db $EC - Y - X * 7
    ENDR
ENDR
assert HIGH(@) == HIGH(CraterTilemaps)

