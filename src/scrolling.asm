INCLUDE "defines.asm"
SECTION "Check Scrolling", ROM0
SCROLL_SPEED equ 2
CheckScrolling::
	ldh a, [hHeldKeys]
	bit PADB_B, a ;check if B is being pressed
	ret z ;skip this whole function otherwise
	; if B is pressed, scroll 1 pixel in the direction pressed on the Dpad
	; hHeldKeys is still in A
	ld b, a
	
CheckUp:
	bit PADB_UP, b
	jr z, .notUp
	ldh a, [hSCY]
	sub SCROLL_SPEED ;scroll 2 px
	;check if the range is valid
	cp SCRN_VY - SCRN_Y
	jr c, .noClamp
	cp 256 - STATUS_BAR_HEIGHT
	jr nc, .noClamp
.Clamp;otherwise, clamp the vulue to its minimum
	ld a, 256 - STATUS_BAR_HEIGHT
.noClamp
	ldh [hSCY], a
.notUp

CheckDown:
	bit PADB_DOWN, b
	jr z, .notDown
	ldh a, [hSCY]
	add SCROLL_SPEED ;scroll 2 px
	;check if the range is valid
	cp SCRN_VY - SCRN_Y
	jr c, .noClamp
	cp 256 - STATUS_BAR_HEIGHT
	jr nc, .noClamp
.Clamp;otherwise, clamp the vulue to its maximum
	ld a, SCRN_VY - SCRN_Y
.noClamp
	ldh [hSCY], a
.notDown

CheckLeft:
	bit PADB_LEFT, b
	jr z, .notLeft
	ldh a, [hSCX]
	cp SCROLL_SPEED ;will a scroll put us past the edge of the screen?
	jr nc, .noClamp 
	;if so, then clamp the scroll register to it's limit
	ld a, SCROLL_SPEED ; add SCROLL_SPEED because the SCROLL_SPEED is about to be subtracted away
.noClamp 
	sub SCROLL_SPEED ;scroll 2 px
	ldh [hSCX], a
.notLeft

CheckRight:
	bit PADB_RIGHT, b
	ret z
	ldh a, [hSCX]
	cp SCRN_VX - SCRN_X - SCROLL_SPEED + 1 ;will a scroll put us past the edge of the screen?
	jr c, .noClamp 
	;if so, then clamp the scroll register to it's limit
	ld a, SCRN_VX - SCRN_X - SCROLL_SPEED ; subtract SCROLL_SPEED because the SCROLL_SPEED is about to be added back
.noClamp 
	add SCROLL_SPEED ;scroll 2 px
	ldh [hSCX], a
    ret