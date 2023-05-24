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

	;init the green that goes with this tilemap
	ld hl, Map01Green
	ld de, $9C00 + SCRN_VX_B * (STATUS_BAR_HEIGHT / 8) ;in the 9C00 tilemap, after the statusbar
	ld a, SCRN_Y_B - (STATUS_BAR_HEIGHT / 8) ;number of rows left in the screen
	call UnPB8ScreenWidth




	;init other stuff
	call InitStatusBar
	call InitAimArrow
	call InitScore

	; set the green corrdinates
	ld a, LOW((19 * 8) << 4)
	ldh [hGreenCoordY], a
	ld a, HIGH((19 * 8) << 4)
	ldh [hGreenCoordY+1], a
	ld a, LOW((3 * 8) << 4)
	ldh [hGreenCoordX], a
	ld a, HIGH((3 * 8) << 4)
	ldh [hGreenCoordX+1], a
	
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

	
	
	;setup the LYC interrupt
	ld a, HIGH(StatusBarLYCTable)
	ldh [hLYCTableHigh], a

	;turn the LCD back on with the hLCDC value set when initing the statusbar
	ldh a, [hLCDC]
	ldh [rLCDC], a

  
	xor a
	ldh [hGameState], a ; initialize to a neutral game state
	jp MainLoop



ExampleTilemap:
	INCBIN "res/Map01.maintileset.tilemap.pb16"
ExampleTilemapEnd:

SECTION "Map01 Green", ROMX
Map01Green:
	INCBIN "res/Map01_green.maintileset.tilemap.pb8"

SECTION "main tileset", ROM0
MainTilesetPB16:
	INCBIN "res/maintileset.2bpp.pb16"

SECTION "status bar LYC table", ROM0, ALIGN[8] ;this table will be read by the LYC handler
	;the format is like this:
	; 1: *NEXT* scaline number minus 1 for handling time
	; 2: value to write to LCDC on the *CURRENT* LYC scanline
	; this can repeat up to 128 times, but the table must start on a page boundary
	; at the end of the table, the next scanline number should be 1.
StatusBarLYCTable::
    db 8 - 1 ;at line 8 we disable sprites
    db 0 ; this is the argument for LYC 0. It isn't used rn

    db STATUS_BAR_HEIGHT - 1 ;at line 16 we turn off the window and start actually drawing the golf course using the bg
    db LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINON | LCDCF_BG8000 | LCDCF_BGON ;line 10 sprite disable

    db LYC_TABLE_END ;finish off the table
    db LCDCF_ON | LCDCF_OBJON | LCDCF_BGON ;LCDC for main golf course