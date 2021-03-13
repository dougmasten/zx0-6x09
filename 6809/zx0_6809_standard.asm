; zx0_6809_standard.asm - ZX0 decompressor for M6809 - 95 bytes
; Written by Doug Masten, based on the ZX0 Z-80 decompressor by Einar Saukas.
;
; ZX0 compression algorithms are (c) 2021 Einar Saukas,
; see https://github.com/einar-saukas/ZX0


                   ifdef ZX0_VAR1
zx0_bit            equ ZX0_VAR1        ; use DP memory
                   endc


;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, Y
; Description : Decompress ZX0 data
;------------------------------------------------------------------------------
; Options:
;
;   ZX0_VAR1
;     Defined variable to point to a DP memory location for a space and
;     speed optimization.
;       ex. ZX0_VAR1 equ $23
;
;   ZX0_ONE_TIME_USE
;     Defined variable to disable re-initialization of variables. Enable
;     this option for one-time use of depacker for smaller code size.
;       ex. ZX0_ONE_TIME_USE equ 1
;
zx0_decompress
                   ifndef ZX0_ONE_TIME_USE
                     ldd #$ffff
                     std zx0_offset+2  ; init offset = -1
                     lda #$80
                     sta zx0_bit       ; init bit stream
                   else
                     ifdef ZX0_VAR1
                       lda #$80
                       sta zx0_bit     ; init bit stream
                     endc
                   endc

; 0 - literal (copy next N bytes from compressed data)
zx0_literals       bsr zx0_elias       ; obtain length
                   tfr d,y
loop@              ldb ,x+             ; copy literals
                   stb ,u+
                   leay -1,y
                   bne loop@
                   lsl zx0_bit         ; get next bit
                   bcs zx0_new_offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   bsr zx0_elias       ; obtain length
zx0_copy           pshs x              ; save reg X
                   tfr d,x             ; setup length
zx0_offset         leay >$ffff,u       ; calculate offset address
loop@              ldb ,y+             ; copy match
                   stb ,u+
                   leax -1,x
                   bne loop@
                   puls x              ; restore reg X
                   lsl zx0_bit         ; get next bit
                   bcc zx0_literals

; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     bsr zx0_elias       ; obtain offset MSB
                   negb                ; adjust for negative offset (set carry for RORA below)
                   beq zx0_eof         ; eof? (length = 256) if so exit
                   tfr b,a             ; transfer to MSB position
                   ldb ,x+             ; obtain LSB offset
                   rora                ; last offset bit becomes first length bit
                   rorb                ;  "     "     "    "      "     "      "
                   std zx0_offset+2    ; preserve new offset
                   ldd #1              ; set elias = 1
                   bcs skip@           ; test first length bit
                   bsr zx0_backtrace   ; get elias but skip first bit
skip@              addd #1             ; elias = elias + 1
                   bra zx0_copy        ; copy new offset match


; interlaced elias gamma coding
zx0_elias          ldd #1              ; set elias = 1
                   bra start@
;
zx0_backtrace
loop@              lsl zx0_bit         ; get next bit
                   rolb
                   rola
start@             lsl zx0_bit         ; get next bit
                   bne skip@
                   pshs a              ; save reg A
                   lda ,x+             ; load another 8-bits
                   rola                ; get next bit
                   sta zx0_bit         ; save bit stream
                   puls a              ; restore reg A
skip@              bcc loop@
zx0_eof            rts


; bit stream
                   ifndef ZX0_VAR1
zx0_bit            fcb $80
                   endc
