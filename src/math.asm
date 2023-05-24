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

SECTION "Signed H Times Signed C", ROM0
    /* signed 8bit by unsigned 8bit multiplication
    Params:
    H: Signed multiplicand
    C: Signed multiplicand
    
    Returns:
    HL: signed 16-bit result 
    C: preserved multiplicand
    B: zero

    Destroys A and doesn't touch DE

    this works basically the same as the signed x unsigned routine above, 
    but uses the +(256 * -Factor) modification for both factors
    */
SignedATimesSignedC::
    ld h, a
SignedHTimesSignedC::

    xor a ;clear our workspace
    ld l, a
    ld b, a 

    ;if C is negative, subtract H from a
    bit 7, c
    jr z, .cNotNegative 
    sub h
.cNotNegative    
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

SECTION "Signed BC Times A", ROM0
    /* signed 16bit by unsigned 8bit multiplication
    Params:
    BC: Signed multiplicand
    A: Unsigned multiplicand
    
    Returns:
    AHL: signed 24-bit result 
    BC: preserved multiplicand
    E: 0

    Destroys HL, D

    this works basically the same as the 8-bit signed x unsigned routine above, 
    but stores positive C in D instead of negative C in A
    */

SignedBCTimesA:: 
    ld hl, 0 ;clear our workspace
    ld d, l
    ld e, l

    bit 7, b ;check if BC is negative
    jr z, .positive
    ld d, a ;get a into d so it can be subtracted later
    ;now d has a if BC was negative, or 0 if it was positive
.positive
    ;optimized first iteration
    add a 
    jr nc, :+
    add hl, bc

:
    REPT 7 ; the other 7 iterations are standard binary long multiplication
    add hl, hl
    rla
    jr nc, :+
    add hl, bc
    adc e
:
    ENDR

    ;now we finish off by subtracting d from a to correct for the sign
    sub d ;this effectively subtracts A * 65536 from the result
    
    ret


SECTION "H Times C", ROM0
;This one is unsigned with 16-bit output
/* Params:
    H: Unsigned multiplier
    C: Unsigned multiplicand
    
    Returns:
    HL: Unsigned 16-bit result 
    C: preserved multiplicand
    B: zero

    doesn't touch A or DE
    */
HTimesC::
    ld b, 0 ; clear our workspace
    ld l, b

    ;optimized first iteration
    add hl, hl
    jr nc, :+   
    ld l, c ;we can load instead of add for this first round
:
    REPT 7 ; the other 7 iterations are standard binary long multiplication
    add hl, hl
    jr nc, :+
    add hl, bc
:
    ENDR
    ret

SECTION "HL Over C", ROM0 ;divides unsigned HL by unsigned C
/* Params:
HL: unsigned 16-bit dividend
C: unsigned 8-bit divisor

Returns:
HL: Unsigned 16-bit quotient
C: Preserved divisor
A: Remainder

Preserves B and DE
*/
HLOverA::
    ld c, a
HLOverC::
    xor a

REPT 16
    add hl, hl
    rla 
    cp c
    jr c, :+
    sub c
    inc l
:
ENDR
    ret


SECTION "Signed Square Table", ROM0, ALIGN[8] 
;this table is meant to be used with the matching square root table to find magnitudes of vectors
SignedSquareTable::
    FOR I, 0, 128.0, 1.0
        db ceil(mul(255.0,div(pow(I,2.0),pow(128.0,2.0))))>>16
    ENDR
    FOR I, -128.0, 0, 1.0
        db ceil(mul(255.0,div(pow(I,2.0),pow(128.0,2.0))))>>16
    ENDR

SECTION "Square Root Table", ROM0, ALIGN[9]

SqrtTable::
    FOR I, 0, 511.0, 1.0 ;the last byte would never be used since $FF + $FF = $1FE
        ; db sqrt(I * 128^2 / 255)
        ; or equivalently, 128 * sqrt(I / 255)
        db floor( pow( mul(pow(128.0,2.0), div(I,255.001)) ,0.5))>>16 ;the .001 is a dirty hack to stay within the 16.16 range these constants use
    ENDR


SECTION "magnitude of vector", ROM0
; gets the 8-bit magnitude of of a signed vector components in A and B
; returns result in A
; clobbers hl
GetVectorMagnitude:: ;uses pythagorean theorem and square/sqrt tables
    ld h, HIGH(SignedSquareTable)
    ld l, a
    ld a, [hl] ;get the first square

    ld l, b
    add [hl] ;get the sum of squares

    ld l, a
    ld h, HIGH(SqrtTable) >> 1
    rl h
    ld a, [hl] ;get the square root

    ret

SECTION "Convert to Decimal", ROM0

; Converts an 8-bit value to decimal. From @PinoBatch
; Param A the value
; returns A: tens and ones digits; B[1:0]: hundreds digit;
; B[7:2]: unspecified
AtoBCD::

    swap a
    ld b,a
    and $0F  ; bits 3-0 in A, range $00-$0F
    or a     ; for some odd reason, AND sets half carry to 1
    daa      ; A=$00-$15
  
    sla b
    adc a
    daa
    sla b
    adc a
    daa      ; A=$00-$63
    rl b
    adc a
    daa
    rl b
    adc a
    daa
    rl b
    ret

