INCLUDE "defines.asm"
SECTION "Intro", ROMX

Intro::
DisableScreen:
	xor a ;ld a, LCDCF_OFF
	ldh [hLCDC], a ; this will be commited to LCDC by the Vblank interrupt next frame
	;now we cant 'rst waitVblank' because if the lcd gets disabled before the halt, this will deadlock because there will be no more Vblanks.
	;so we check LCDC in a loop to see if the screen is off
.checkcompletion
	ldh a, [rLCDC]
	rlca ;rotate bit 7 (LCD on Flag) into carry
	jr c, .checkcompletion

	;now the screen is off

	ld hl, $8800 ;this is where we'll put the tiles for now
	ld de, ExampleTiles
	ld bc, ExampleTilesEnd - ExampleTiles
	call Memcpy

	ld hl, $9800;this is where we'll put the tilemap for now
	ld de, ExampleTilemap
	ld bc, ExampleTilemapEnd - ExampleTilemap
	call Memcpy

	;turn the LCD back on

	ld a, LCDCF_ON | LCDCF_BGON ;bare minimum to have a bg
	ldh [hLCDC], a
	ldh [rLCDC], a

	;lockup
	jr @




ExampleTilemap:
	INCBIN "res/Map01.golftilemap"
ExampleTilemapEnd:
ExampleTiles:
	INCBIN "res/golfassets.2bpp"
ExampleTilesEnd:
