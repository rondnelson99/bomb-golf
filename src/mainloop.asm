INCLUDE "defines.asm"
SECTION "Start Main Loop", ROM0

MainLoop::
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
    jr .doneinput


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
    jr .doneinput

.perhapsReset
	ldh a, [hCanSoftReset]
	and a
	jr z, .dontReset
	jp Reset

.doneinput
	; Now, call an appropriate function based on the game state
	ldh a, [hGameState]

	cp a, 0 ; neither green nor stroke
	jr nz, .notIdleCourse
	call IdleCourse
	jr .doneMainLoop

.notIdleCourse
	cp a, STROKE_FLAG ; off-green stroke
	jr nz, .notStroke
	call UpdateSwing
	jr .doneMainLoop

.notStroke
	cp a, GREEN_FLAG ; on-green view
	error nz ; If we're in an invalid state, then crash
	call GreenFunctions
	jr .doneMainLoop




.doneMainLoop



	ld a, HIGH(wShadowOAM) ;queue OAM DMA
	ldh [hOAMHigh], a
	rst WaitVBlank
	jp MainLoop

SECTION "Idle course functions", ROM0
IdleCourse:
	;first check if we need to switch to the green view. This is triggered by the user pressing select.
	ldh a, [hPressedKeys]
	bit PADB_SELECT, a
	jp nz, SwitchToGreen
	call CheckScrolling

	;check if the player is trying to swing
	call CheckSwing

	;Process objects
	;call ProcessCrosshair
	call DrawBall
	jp CheckAiming ;tail call



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

; Holds a set of flags defining what is currently happening in the game.
/*
The bits are as follows:
0: 1 if viewing the green, 0 if looking at the whole course
1: 1 if the user is in a stroke, 0 if not
other bits are unused 
*/
hGameState:: db
GREEN_FLAG  equ %00000001
STROKE_FLAG equ %00000010
EXPORT GREEN_FLAG, STROKE_FLAG

