INCLUDE "defines.asm"
SECTION "Check Scrolling", ROM0
SCROLL_SPEED equ 2
MIN_CAMERA_Y equs "( - STATUS_BAR_HEIGHT)" ;string equate since this isn't constant at assembly time
MAX_CAMERA_Y equ SCRN_VX - SCRN_Y
MAX_CAMERA_X equ SCRN_VX - SCRN_X
;X camera Minimum is implied to be 0
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
	cp MAX_CAMERA_Y
	jr c, .noClamp
	cp MIN_CAMERA_Y
	jr nc, .noClamp
.Clamp;otherwise, clamp the vulue to its minimum
	ld a, MIN_CAMERA_Y
.noClamp
	ldh [hSCY], a
.notUp

CheckDown:
	bit PADB_DOWN, b
	jr z, .notDown
	ldh a, [hSCY]
	add SCROLL_SPEED ;scroll 2 px
	;check if the range is valid
	cp MAX_CAMERA_Y
	jr c, .noClamp
	cp 256 - STATUS_BAR_HEIGHT
	jr nc, .noClamp
.Clamp;otherwise, clamp the vulue to its maximum
	ld a, MAX_CAMERA_Y
.noClamp
	ldh [hSCY], a
.notDown

CheckLeft:
	bit PADB_LEFT, b
	jr z, .notLeft
	ldh a, [hSCX]
	sub SCROLL_SPEED ;do the scroll
	jr nc, .noClamp ;did we pass zero?
	;if so, then clamp the scroll register to it's limit
.clamp
	xor a ;clamp to zero
.noClamp 
	ldh [hSCX], a
.notLeft

CheckRight:
	bit PADB_RIGHT, b
	ret z
	ldh a, [hSCX]
	add SCROLL_SPEED
	cp SCRN_VX - SCRN_X + 1 ;did the scroll put us past the edge of the screen?
	jr c, .noClamp 
	;if so, then clamp the scroll register to it's limit
	ld a, SCRN_VX - SCRN_X
.noClamp 
	ldh [hSCX], a
    ret

SECTION "scroll to sprite 12.4", ROM0 ;this should be called every frame when the camera is following the ball, or any other sprite with a 12.4 position
;HL: pointer to 12.4 y position followed by X position

ScrollToSprite124::
	ld a, [hl+] ;low byte Y
	ld b, a
	ld a, [hl+] ;high byte Y
	cp 16 ;make sure it's within the 256 px tilemap range
	ret nc ;if it's out of range, just leave the camera where it is.
	xor b
	and $0f
	xor b ;masked merge
	swap a 

	sub (SCRN_Y + STATUS_BAR_HEIGHT) / 2 
CheckCenterY:
	;if that's in the valid camera range, that's great! if not, we need to clamp it.
	cp MIN_CAMERA_Y
	assert MIN_CAMERA_Y < 0 
	;since the minimum is less then 0, in unsigned math, the position must be less then the camera max OR greater than the camera min
	cp MAX_CAMERA_Y + 1
	jr c, .noClamp
	cp MIN_CAMERA_Y
	jr nc, .noClamp
.clamp
	;to clamp, we want to return see if the original position was in the bottom half of the screen or not
	;so se can compare the opposite of value we subtracted earlier
	cp - (SCRN_Y + STATUS_BAR_HEIGHT) / 2 
	jr nc, .clampTop
.clampBottom
	ld a, MAX_CAMERA_Y
	jr .noClamp
.clampTop
	ld a, MIN_CAMERA_Y
.noClamp
	ld c, a ;wait until we know it's in view on the X axis before writing it
	
	;do do the same for X
CheckCenterX:
	ld a, [hl+] ;low byte X
	ld b, a
	ld a, [hl+] ;high byte X
	cp 16 ;make sure it's within the 256 px tilemap range
	ret nc ;if it's out of range, just leave the camera where it is.
	xor b
	and $0f
	xor b ;masked merge
	swap a 

	sub SCRN_X / 2 ;get the camera position that would center it
	jr nc, .noClampLeft ;if that resulted in a borrow, then the centered camera would be negative, so clamp to 0
.clampLeft
	xor a
	jr .noClamp
.noClampLeft
	;if that's in the valid camera range, that's great! if not, we need to clamp it.
	cp MAX_CAMERA_X + 1 ;the position must be less then the camera max. 
	jr c, .noClamp
.clampRight
	ld a, MAX_CAMERA_X
.noClamp
	;finally, write the X and Y scroll values
	ldh [hSCX], a
	ld a, c
	ldh [hSCY], a

	ret

