; zx0_6809_mega.asm - ZX0 decompressor for M6809 - 188 bytes
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

                   ifndef ZX0_DISABLE_SAVE_REGS
zx0_exit           puls cc,dp,pc       ; restore registers and exit
                   else
zx0_exit           equ zx0_rts         ; just exit
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
                   bcs zx0_length2     ; test first length bit (length = 2)
                   ldb #1              ; set elias = 1
                   bsr zx0_elias_loop  ; get elias but skip first bit
                   leay 1,y            ; elias = elias + 1
                   bra zx0_copy        ; go copy match
zx0_length2        ldy #2              ; length = 2
zx0_copy           stx <save_x@+1      ; save reg X
zx0_offset         leax >$ffff,u       ; calculate offset address
loop@              ldb ,x+             ; copy match
                   stb ,u+             ;  "    "
                   leay -1,y           ; decrement loop counter
                   bne loop@           ; loop until done
save_x@            ldx #$ffff          ; restore reg X
                   lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - literal (copy next N bytes from compressed data)
zx0_literals       lsla                ; get next bit
                   bcs zx0_literal1    ; length = 1? (or bit stream empty)
zx0_literals_more  ldb #1              ; set elias = 1
                   bsr zx0_elias_loop  ; obtain length
loop@              ldb ,x+             ; copy literals
                   stb ,u+             ;  "    "
                   leay -1,y           ; decrement loop counter
                   bne loop@           ; loop until done
zx0_literals_done  lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   lsla                ; get next bit
                   bcs zx0_last1       ; length = 1? (or bit stream empty)
zx0_last_more      ldb #1              ; set elias = 1
                   bsr zx0_elias_loop  ; obtain length
                   bra zx0_copy        ; go copy last offset block

zx0_last1          bne skip@           ; is bit stream empty? no, branch (length = 1)
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcc zx0_last_more   ; more elias bits? yes, branch
skip@              ldy #1              ; length = 1
                   bra zx0_copy        ; go copy last offset block

zx0_literal1       bne skip@           ; is bit stream empty? no, branch (length = 1)
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcc zx0_literals_more ; more elias bits? yes, branch
skip@              ldb ,x+             ; copy one literal
                   stb ,u+             ;  "   "     "
                   bra zx0_literals_done ; get next block


; interlaced elias gamma coding (returns value in reg Y)
zx0_elias_loop     lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc zx0_elias_loop  ; loop until done
                   beq zx0_reload      ; is bit stream empty? yes, refill it
zx0_elias_done     stb <zx0_length+1   ; return elias value in reg Y
                   ldy <zx0_length     ;  "      "     "    "  "   "
zx0_rts            rts                 ; return

; elias value can't exceed 8 bits until after a reload
zx0_reload         lda ,x+             ; load another group of 8 bits
                   rola                ; are we done?
                   bcs zx0_elias_done  ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_elias_done  ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_elias_done  ; yes, exit
                   lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   lsla                ; are we done?
                   bcs zx0_elias_done  ; yes, exit

; long elias gamma coding
loop@              lsla                ; get next bit
                   rolb                ; rotate bit into elias value
                   rol <zx0_length     ;  "      "   "    "     "
                   lsla                ; is bit stream empty?
                   bne skip@           ; no, branch
                   lda ,x+             ; reload bit stream
                   rola                ; are we done?
skip@              bcc loop@           ; no, loop again
                   bsr zx0_elias_done  ; return elias value in reg Y
                   clr <zx0_length     ; reset MSB for next time
                   rts

zx0_length         fdb 0               ; elias value (MSB must be zero)


; safety check
zx0_dp_end         equ */256
                   ifne zx0_dp-zx0_dp_end
                   error "zx0_decompress code crossed over DP memory space"
                   endc
