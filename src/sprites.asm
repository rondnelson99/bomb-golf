SECTION UNION "Shadow OAM", WRAM0
;here we define OAM entries for the main course view

OBJ_METER:: ;power meter on statusbar
    ds 4 ;reserve 1 OAM entry
OBJ_METER_COPY:: ;copy of meter to continue showing power whice lining up aim
    ds 4
OBJ_CROSSHAIR::
    ds 4
OBJ_BALL::
    ds 4
OBJ_SHADOW::
    ds 4 ;shadow under the ball
OBJ_ARROW::
    ds 4 ;arrow pointing in the ball direction