INCLUDE "defines.asm"

SECTION "unPB8", ROM0 ;PB8 is good for 1bpp graphics and sometimes tilemaps.

UnPB8::
.pb8BlockLoop
    ;unpack b blocks from [hl] to [de]. 8 byte blocks
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
    ld [de], a
    inc de ; inc de
    sla c
    jr nz, .pb8BitLoop

    dec b
    jr nz, .pb8BlockLoop
    ret

SECTION "UnPB8 Screen Width", ROM0 ;Unpack a PB8 Tilemap, but skip 12 bytes after every 20 bytes.
;This is used to unpack tilemaps that have the same width as the screen, like the statusbar or a green
;However, it is not meant to be used while the screen is running.

; HL = Source address
; DE = Destination address
; A = Number of tilemap rows to unpack



;this works like regular PB8, but uses an additional counter so it knows when to skip the next 12 bytes.
UnPB8ScreenWidth::

    ldh [hTempByte2], a ;store the row count in a temp variable
    ld b, SCRN_X_B ;countdown until we skip some bytes
.pb8BlockLoop
    ld c, [hl] ;load the ring counter with the re-used bytes in this block
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
    ld [de], a ;store the byte
    inc de 
    dec b ;count down until the skip
    jr nz, .dontSkip


    ldh [hTempByte], a

    ;decrement the row count to see if we can exit
    ldh a, [hTempByte2] ;load the row count
    dec a
    ret z ;just exit if we're done. We havent stacked anything so this is safe.
    ldh [hTempByte2], a ;store the row count away again


    ; now add 12 to de    
    ld a, e
    add SCRN_VX_B - SCRN_X_B
    ld e, a
    adc d
    sub e
    ld d, a

    ld a, [hTempByte]

    ld b, SCRN_X_B ;refresh the counter

.dontSkip
    sla c
    jr nz, .pb8BitLoop
    jr .pb8BlockLoop




    
