SECTION UNION "Shadow OAM", WRAM0
;here we define OAM entries for the main course view

OBJ_METER:: ;power meter on statusbar
    ds 4 ;reserve 1 OAM entry
OBJ_CROSSHAIR::
    ds 4
OBJ_BALL::
    ds 4
OBJ_ARROW::
    ds 4 ;arrow pointing in the ball direction