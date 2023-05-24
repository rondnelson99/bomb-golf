
INCLUDE "defines.asm"

SECTION "Init Score & update Score", ROM0
; initializes the score on the status bar
InitScore::
    xor a
    ld [hPlayerScore], a

    jr UpdateScore

IncrementScore::
    ld a, [hPlayerScore]
    inc a
    ld [hPlayerScore], a

    ; fall through to update

; updates the score on the status bar
UpdateScore::
    ; first, convert the score to bcd
    ld a, [hPlayerScore]
    call AtoBCD
    ; now a contains the tens in the high nibble and the ones in the low nibble
    ld b, a
    swap b
    and $0f ; get the ones

    wait_vram_hl
    ; now we have 17 cycles of VRAM time
    ld [TILEMAP_SCORE + 1], a ; write the ones digit
    ; 13 cycles left
    ld a, b
    and $0f ; get the tens
    ; 10 cycles left
    ld [TILEMAP_SCORE], a ; write the tens digit
    ; 6 cycles left

    ret
    






SECTION "Score HRAM", HRAM
hPlayerScore:: db