INCLUDE "defines.asm"

SECTION "signed H times C", ROM0
    /* signed 8bit by unsigned 8bit multiplication
    Params:
    H: Signed multiplicand
    C: Unsigned multiplicand
    
    Returns:
    HL: signed 16-bit result 
    C: preserved multiplicand
    B: zero

    Destroys A and doesn't touch DE

    If h is positive, this works just like regular long multiplication.
    If h is negative, it works usign the distributive property.
    In this case we want (unsigned H - 256) * C
    But this is the same as (Unsigned H * C) + (256 * -C)
    So if H is negative, we put -C into A (which is otherwise zero), and add it to the high byte of the product (thus multiplying it by 256)
    */
SignedATimesC::
    ld h, a
SignedHTimesC:: 
    xor a ;clear our workspace
    ld l, a
    ld b, a 

    ;special first iteration
    add hl, hl ;this shifts the sign of the signed multiplier into carry
    jr nc, :+
    ;for the multiplication part, we can load instead of add for this first round
    ld l, c
    ;but if we're hare then l is negative, so we need get negative c into a to add it later
    sub c ;a was zero before
    ;now a is negative c if h was negative, or zero if x was positive
:
    REPT 7 ; the other 7 iterations are standard binary long multiplication
    add hl, hl
    jr nc, :+
    add hl, bc
:
    ENDR

    ;now we finish off by adding a to h to correct for the sign
    add a, h
    ld h, a
    
    ret




    

