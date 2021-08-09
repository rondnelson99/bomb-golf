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

	ld hl, $8000 ;decompress the sprite tiles to sprite tile VRAM
	ld de, PB16SpriteTiles
	ld b, 128 ;copy 128 tiles. In PB16, each packet is 16 bytes or 1 tile
	call pb16_unpack_block

	;ld hl, $8800 ;this is where we'll put the tiles for now, but hl will already be pointed here after the last function
	ld de, ExampleTiles
	ld bc, ExampleTilesEnd - ExampleTiles
	call Memcpy

	ld hl, $9800;this is where we'll put the tilemap for now
	ld de, ExampleTilemap
	ld b, 1024/16 ;1024 tilemap entries divided by 16 bytes per packet
	call pb16_unpack_block

	;init other stuff
	call InitCrosshair

	xor a
	ld [wCraterVRAMSP], a
	ld a, HIGH($9800)
	ld [wCraterVRAMSP + 1], a

	;turn the LCD back on

	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON ;bg + sprites
	ldh [hLCDC], a
	ldh [rLCDC], a

MainLoop:

	call CheckScrolling

	;Process objects
	call ProcessCrosshair




	ld a, HIGH(wShadowOAM)
	ldh [hOAMHigh], a
.end
	rst WaitVBlank
	jr MainLoop



	




ExampleTilemap:
	INCBIN "res/Map01.golf.tilemap.pb16"
ExampleTilemapEnd:

ExampleTiles:
	INCBIN "res/golf.2bpp"
ExampleTilesEnd:

PB16SpriteTiles:
	INCBIN "res/spriteTiles.2bpp.pb16"
