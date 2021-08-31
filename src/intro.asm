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

	ld hl, $8000 ;decompress the main tiles to VRAM
	ld de, MainTilesetPB16
	ld b, 128 + 60 ;copy 128 $8000 + 60 $8800 tiles. In PB16, each packet is 16 bytes or 1 tile
	call pb16_unpack_block



	ld hl, $9800;this is where we'll put the tilemap for now
	ld de, ExampleTilemap
	ld b, 1024/16 ;1024 tilemap entries divided by 16 bytes per packet
	call pb16_unpack_block

	;init other stuff
	;call InitCrosshair
	call InitStatusBar
	call InitAimArrow
	
	xor a
	ld hl, wBallY ;this is a 12.4 coord, with the x coord after it
	ld [hl+], a
	ld [hl], 144 / 2 / 16
	inc l
	ld [hl+], a
	ld [hl], 160 / 2 / 16
	inc l
	;and now comes the z coord, which will jus be set to 0
	ld [hl+], a
	ld [hl+], a



	xor a
	ld [wCraterVRAMSP], a
	ld a, HIGH($9800)
	ld [wCraterVRAMSP + 1], a

	;turn the LCD back on with the hLCDC value set when initing the statusbar

	ldh a, [hLCDC]
	ldh [rLCDC], a

MainLoop:

	call CheckScrolling

	;check if the player is trying to swing
	call CheckSwing

	

	;Process objects
	;call ProcessCrosshair
	call DrawBall
	call CheckAiming




	ld a, HIGH(wShadowOAM)
	ldh [hOAMHigh], a
.end
	rst WaitVBlank
	jr MainLoop



	




ExampleTilemap:
	INCBIN "res/Map01.maintileset.tilemap.pb16"
ExampleTilemapEnd:

SECTION "main tileset", ROM0
MainTilesetPB16:
	INCBIN "res/maintileset.2bpp.pb16"

