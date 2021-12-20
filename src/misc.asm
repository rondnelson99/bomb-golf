
INCLUDE "defines.asm"

INCLUDE "misc/rand.asm"
EXPORT randstate ; Defined in the above, exported here to avoid touching the file


SECTION "Memcpy", ROM0

; Copies a block of memory somewhere else
; @param de Pointer to beginning of block to copy
; @param hl Pointer to where to copy (bytes will be written from there onwards)
; @param bc Amount of bytes to copy (0 causes 65536 bytes to be copied)
; @return de Pointer to byte after last copied one
; @return hl Pointer to byte after last written one
; @return bc 0
; @return a 0
; @return f Z set, C reset
Memcpy::
	; Increment B if C is non-zero
	dec bc
	inc b
	inc c
.loop
	ld a, [de]
	ld [hli], a
	inc de
	dec c
	jr nz, .loop
	dec b
	jr nz, .loop
	ret

SECTION "misc HRAM", HRAM
hTempByte:: ;use this to store temporary bytes, like a backup of the accumulator. 
	;As long as you don't call any functions before reading it back, it works fine and is fast
	db
hTempByte2:: ;in case you need to store two bytes
	db