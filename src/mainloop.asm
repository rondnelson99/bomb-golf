INCLUDE "defines.asm"
SECTION "Start Main Loop", ROM0
;this function is called at the start of every main loop in the game. It handles reading input mostly.
StartMainLoop::
    ;read input
    ld c, LOW(rP1)
	ld a, $20 ; Select D-pad
	ldh [c], a
REPT 6
	ldh a, [c]
ENDR
	or $F0 ; Set 4 upper bits (give them consistency)
	ld b, a

	; Filter impossible D-pad combinations
	and $0C ; Filter only Down and Up
	ld a, b
	jr nz, .notUpAndDown
	or $0C ; If both are pressed, "unpress" them
	ld b, a
.notUpAndDown
	and $03 ; Filter only Left and Right
	jr nz, .notLeftAndRight
	; If both are pressed, "unpress" them
	inc b
	inc b
	inc b
.notLeftAndRight
	swap b ; Put D-pad buttons in upper nibble

	ld a, $10 ; Select buttons
	ldh [c], a
REPT 6
	ldh a, [c]
ENDR
	; On SsAB held, soft-reset
	and $0F
	jr z, .perhapsReset
.dontReset

	or $F0 ; Set 4 upper bits
	xor b ; Mix with D-pad bits, and invert all bits (such that pressed=1) thanks to "or $F0"
	ld b, a

	; Release joypad
	ld a, $30
	ldh [c], a

	ldh a, [hHeldKeys]
	cpl
	and b
	ldh [hPressedKeys], a
	ld a, b
	ldh [hHeldKeys], a

    ;now, count how long each button has been held
    ld hl, hFramesHeldA
    ;hHeldKeys is in b
    ld c, 8 ;count of buttons to loop through
.loop
    rr b ;rotate button pressed flag into carry
    jr c, .held

    ;if button was not held, reset counter
    xor a
    ld [hl+], a
    dec c
    jr nz, .loop
    ret


    ;alternate end of loop
.held
    ;if the button is pressed, add 1 to the counter
    inc [hl]
    jr nz, .noOverflow
    ;if it overflowed, decrement it to clamp at 255
    dec [hl]
.noOverflow
    inc l ;move to the next byte
    dec c
    jr nz, .loop
    ret

.perhapsReset
	ldh a, [hCanSoftReset]
	and a
	jr z, .dontReset
	jp Reset



SECTION "Main Loop HRAM", HRAM
; Keys that are currently being held, and that became held just this frame, respectively.
; Each bit represents a button, with that bit set == button pressed
; Button order: Down, Up, Left, Right, Start, select, B, A
; U+D and L+R are filtered out by software, so they will never happen
hHeldKeys:: db
hPressedKeys:: db

; count of how many frames each button has been held for. It caps at 255 so it doesn't overflow.
hFramesHeldA:: db
hFramesHeldB:: db
hFramesHeldSelect:: db
hFramesHeldStart:: db
hFramesHeldRight:: db
hFramesHeldLeft:: db
hFramesHeldUp:: db
hFramesHeldDown:: db

