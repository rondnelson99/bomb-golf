SECTION "unPB8", ROM0 ;PB8 is good for 1bpp graphics and sometimes tilemaps.

UnPB8::
.pb8BlockLoop
    ;unpack b blocks from hl to de. 8 byte blocks
    ld c, [hl]
    inc hl

    ; Shift a 1 into lower bit of shift value.  Once this bit
    ; reaches the carry, B becomes 0 and the byte is over
    scf
    rl c

.pb8BitLoop
    ; If not a repeat, load a literal byte
    jr c,.pb8Repeat
    ld a, [hli]
.pb8Repeat
    ; Decompressed data uses colors 0 and 3, so write twice
    ld [de], a
    inc de ; inc de
    sla c
    jr nz, .pb8BitLoop

    dec b
    jr nz, .pb8BlockLoop
    ret

