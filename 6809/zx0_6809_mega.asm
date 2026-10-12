; zx0_6809_mega.asm - ZX0 decompressor for M6809 - 371 bytes
; Written for the LWTOOLS assembler, http://www.lwtools.ca/.
;
; Copyright (c) 2021 Doug Masten
; ZX0 compression (c) 2021 Einar Saukas, https://github.com/einar-saukas/ZX0
;
; This software is provided 'as-is', without any express or implied
; warranty. In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.



; get offset MSB elias value into reg B (256 wraps to 0)
zx0_elias_msb      macro
                   ldb #1              ; set elias = 1
                   lsla                ; get next bit
                   bcc loop@           ; more elias bits? yes, branch
                   bne done@           ; is bit stream empty? no, branch (elias = 1)
reload@            lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcs done@           ; are we done? yes, branch
loop@              lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc loop@           ; loop until done
                   beq reload@         ; is bit stream empty? yes, refill it
done@              equ *
                   endm


;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, Y
; Description : Decompress ZX0 data (version 1)
;
; Copies two bytes at a time. The first ~200 bytes (up to zx0_dp_end) use DP
; addressing and must not cross a 256-byte page; the assembler reports an
; error if they do. Rarely used code after that may be anywhere.
;------------------------------------------------------------------------------
; Options:
;
;   ZX0_ONE_TIME_USE
;     Defined variable to disable re-initialization of variables. Enable
;     this option for one-time use of depacker for smaller code size.
;       ex. ZX0_ONE_TIME_USE equ 1
;
;   ZX0_DISABLE_SAVE_REGS
;     Defined variable to disable saving registers CC and DP. Enable
;     this option for smaller code size and if calling program will take
;     care of registers CC and DP.
;       ex. ZX0_DISABLE_SAVE_REGS equ 1
;
;   ZX0_DISABLE_DISABLING_INTERRUPTS
;     Defined variable to disable the disabling of interrupts. Enable
;     this option if interrupts are already disable or if IRQ and FIRQ
;     code won't mind register DP being changed.
;       ex. ZX0_DISABLE_DISABLING_INTERRUPTS
;
zx0_decompress
                   ifndef ZX0_DISABLE_SAVE_REGS
                   pshs cc,dp          ; save registers
                   endc

                   ifndef ZX0_DISABLE_DISABLING_INTERRUPTS
                   orcc #$50           ; disable interrupts
                   endc

                   ifndef ZX0_ONE_TIME_USE
                   ldd #$ffff          ; init offset = -1
                   std >zx0_offset+2
                   endc

zx0_dp             equ */256
                   ldd #($80*256)+zx0_dp  ; init bit stream and register DP
                   tfr b,dp
                   setdp zx0_dp
                   bra zx0_literals    ; start with literals


; new offset = -1 overlaps so it can't be copied two bytes at a time
zx0_check_fill     ldb <zx0_offset+2   ; offset = -1?
                   incb                ;  "     "  "
                   bne zx0_not_fill    ; no, branch
                   jmp zx0_new_fill    ; yes, go fill

; new offset with length = 2
zx0_length2        sta <zx0_save_a+1   ; save bit stream
                   ldd <zx0_offset+2   ; copy two bytes from new offset
                   ldd d,u             ;  "   "    "    "    "     "
                   std ,u++            ;  "   "    "    "    "     "
zx0_save_a         lda #$ff            ; restore bit stream
                   bra zx0_match_done  ; get next block

                   ifndef ZX0_DISABLE_SAVE_REGS
zx0_exit           puls cc,dp,pc       ; restore registers and exit
                   else
zx0_exit           rts                 ; just exit
                   endc


; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     zx0_elias_msb       ; obtain MSB offset
                   negb                ; adjust for negative offset (set carry for RORB below)
                   beq zx0_exit        ; eof? (length = 256) if so exit
                   rorb                ; last offset bit becomes first length bit
                   stb <zx0_offset+2   ; save MSB offset
                   ldb ,x+             ; load LSB offset
                   rorb                ; last offset bit becomes first length bit
                   stb <zx0_offset+3   ; save LSB offset
                   incb                ; LSB offset = $ff? (keeps carry)
                   beq zx0_check_fill  ; yes, go check for offset = -1
zx0_not_fill       bcs zx0_length2     ; test first length bit (length = 2)
                   ldb #1              ; set elias = 1
zx0_new_elias      lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc zx0_new_elias   ; loop until done
                   bne zx0_new_length  ; is bit stream empty? no, branch
                   jsr zx0_reload      ; reload bit stream and finish elias
zx0_new_length     addb #1             ; length = elias + 1
                   rorb                ; reg B = byte pairs to copy, carry = odd byte
zx0_copy           stx <save_x@+1      ; save reg X
zx0_offset         leax >$ffff,u       ; calculate offset address
loop@              ldy ,x++            ; copy match two bytes at a time
                   sty ,u++            ;  "    "    "   "     "  "  "
                   decb                ; decrement loop counter
                   bne loop@           ; loop until done
                   bcc save_x@         ; odd byte left? no, branch
                   ldb ,x+             ; copy odd byte
                   stb ,u+             ;  "   "    "
save_x@            ldx #$ffff          ; restore reg X
zx0_match_done     lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - literal (copy next N bytes from compressed data)
zx0_literals       lsla                ; get next bit
                   bcs zx0_literal1    ; length = 1? (or bit stream empty)
zx0_literals_more  ldb #1              ; set elias = 1
zx0_literals_elias lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc zx0_literals_elias ; loop until done
                   bne zx0_literals_ret ; is bit stream empty? no, branch
                   jsr zx0_reload      ; reload bit stream and finish elias
zx0_literals_ret   lsrb                ; reg B = byte pairs to copy, carry = odd byte
loop@              ldy ,x++            ; copy literals two bytes at a time
                   sty ,u++            ;  "     "      "   "     "  "  "
                   decb                ; decrement loop counter
                   bne loop@           ; loop until done
                   bcc zx0_literals_done ; odd byte left? no, branch
zx0_literal_byte   ldb ,x+             ; copy one literal
                   stb ,u+             ;  "   "     "
zx0_literals_done  lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   lsla                ; get next bit
                   bcs zx0_last1       ; length = 1? (or bit stream empty)
zx0_last_more      ldb #1              ; set elias = 1
zx0_last_elias     lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc zx0_last_elias  ; loop until done
                   bne zx0_last_length ; is bit stream empty? no, branch
                   jsr zx0_reload      ; reload bit stream and finish elias
zx0_last_length    lsrb                ; reg B = byte pairs to copy, carry = odd byte
                   ldy <zx0_offset+2   ; offset = -1?
                   leay 1,y            ;  "     "  "
                   bne zx0_copy        ; no, go copy last offset block
                   rolb                ; reg B = length
                   jmp zx0_copy_b      ; go fill

zx0_last1          bne skip@           ; is bit stream empty? no, branch (length = 1)
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcc zx0_last_more   ; more elias bits? yes, branch
skip@              sta <save_a@+1      ; save bit stream
                   ldd <zx0_offset+2   ; copy one byte from last offset
                   ldb d,u             ;  "   "   "    "    "     "
                   stb ,u+             ;  "   "   "    "    "     "
save_a@            lda #$ff            ; restore bit stream
                   bra zx0_match_done  ; get next block

zx0_literal1       bne zx0_literal_byte ; is bit stream empty? no, branch (length = 1)
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcc zx0_literals_more ; more elias bits? yes, branch
                   bra zx0_literal_byte ; go copy one literal


; safety check (only the code above must be in the DP memory page)
zx0_dp_end         equ */256
                   ifne zx0_dp-zx0_dp_end
                   error "zx0_decompress code crossed over DP memory space"
                   endc


; interlaced elias gamma coding (returns 8-bit value in reg B)
zx0_elias_loop     lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc zx0_elias_loop  ; loop until done
                   beq zx0_reload      ; is bit stream empty? yes, refill it
zx0_rts            rts                 ; return

; elias value can't exceed 8 bits until after a reload
zx0_reload         lda ,x+             ; load another group of 8 bits
                   rola                ; are we done?
                   bcs zx0_rts         ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_rts         ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_rts         ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_rts         ; yes, exit

; long elias gamma coding
loop@              lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   rol zx0_length      ;  "      "   "    "     "
                   lsla                ; is bit stream empty?
                   bne skip@           ; no, branch
                   lda ,x+             ; reload bit stream
                   rola                ; are we done?
skip@              bcc loop@           ; no, loop again
                   tst zx0_length      ; elias > 255?
                   beq zx0_rts         ; no, return

; copy all but the last two bytes of a long block here then return elias = 2
; (caller is identified by the LSB of its return address)
                   stb zx0_length+1    ; reg Y = elias - 2
                   ldy zx0_length      ;  "  "   "     "
                   leay -2,y           ;  "  "   "     "
                   clr zx0_length      ; reset MSB for next time
                   sta save_a@+1       ; save bit stream
                   ldb 1,s             ; called from literals?
                   cmpb #zx0_literals_ret%256
                   bne skip@           ; no, copy match
                   bsr zx0_copy_words  ; copy literals
                   bra save_a@         ; return elias = 2
skip@              bsr zx0_copy_match  ; copy match
save_a@            lda #$ff            ; restore bit stream
                   ldb #2              ; elias = 2
                   rts                 ; return

; new offset = -1
zx0_new_fill       ldb #1              ; set elias = 1
                   bcs skip@           ; test first length bit (length = 2)
                   bsr zx0_elias_loop  ; get elias but skip first bit
skip@              incb                ; length = elias + 1 (0 = 256)

; copy reg B bytes (0 = 256) from last offset
zx0_copy_b         sta save_a@+1       ; save bit stream
                   clra                ; reg Y = length
                   tstb                ;  "  "    "
                   bne skip@           ;  "  "    "
                   inca                ;  "  "    "
skip@              tfr d,y             ;  "  "    "
                   bsr zx0_copy_match  ; copy match
save_a@            lda #$ff            ; restore bit stream
                   jmp zx0_match_done  ; get next block

; copy reg Y bytes from last offset (destroys reg A)
zx0_copy_match     ldd zx0_offset+2    ; offset = -1?
                   cmpd #$ffff         ;  "     "  "
                   beq zx0_fill        ; yes, branch
                   stx save_x@+1       ; save reg X
                   leax d,u            ; calculate offset address
                   bsr zx0_copy_words  ; copy match
save_x@            ldx #$ffff          ; restore reg X
                   rts                 ; return

; fill reg Y bytes with last byte (destroys reg A)
zx0_fill           tfr y,d             ; odd length?
                   lsrb                ;  "    "
                   lda -1,u            ; reg D = fill byte twice
                   tfr a,b             ;  "  "   "    "    "
                   bcc loop@           ; even length, branch
                   sta ,u+             ; fill one byte
                   leay -1,y           ; decrement loop counter
                   beq done@           ; branch if done
loop@              std ,u++            ; fill two bytes at a time
                   leay -2,y           ; decrement loop counter
                   bne loop@           ; loop until done
done@              rts                 ; return

; copy reg Y bytes from reg X to reg U (destroys reg A, offset can't be -1)
zx0_copy_words     tfr y,d             ; odd length?
                   lsrb                ;  "    "
                   bcc loop@           ; no, branch
                   lda ,x+             ; copy one byte
                   sta ,u+             ;  "   "   "
                   leay -1,y           ; decrement loop counter
                   beq done@           ; branch if done
loop@              ldd ,x++            ; copy two bytes at a time
                   std ,u++            ;  "   "    "    "  "  "
                   leay -2,y           ; decrement loop counter
                   bne loop@           ; loop until done
done@              rts                 ; return

zx0_length         fdb 0               ; elias value (MSB must be zero)
