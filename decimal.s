PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

value = $0200  ; 2 bytes
mod10 = $0202  ; 2 bytes
message = $0204  ; 6 bytes

E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%11100000 ; Set top 3 pins on port A to output
  sta DDRA

  jsr lcd_init
  lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #$00000001 ; Clear display
  jsr lcd_instruction

  lda #0
  sta message

  ; Initialize value to be the number to convert
  lda number
  sta value
  lda number + 1
  sta value + 1

divide:
  ; Initialize the remainder to 0
  lda #0
  sta mod10
  sta mod10 + 1
  clc

  ldx #16  ; go through the loop 16 times
divloop:
  ; Rotate quotient and remainder left
  rol value
  rol value + 1
  rol mod10
  rol mod10 + 1

  ; a,y = dvidend - divisor
  sec  ; Set carry flag to 1 for subtraction
  lda mod10
  sbc #10  ; Subtract 10 from the remainder
  tay  ; save low byte in Y
  lda mod10 + 1
  sbc #0  ; Subract 0 from the high byte
  bcc ignore_result  ; branch if dividend < divisor
  sty mod10  ; low byte of remainder
  sta mod10 + 1  ; high byte of remainder

ignore_result:
  dex 
  bne divloop
  rol value  ; shift in the last bit of the quotient

  lda mod10
  clc 
  adc #"0"  ; a = a + #"0" + carrybit
  jsr push_char

  ; if value != 0, then continue dividing
  lda value 
  ora value + 1  ; check if any bits are set
  bne divide  ; branch if value != 0

  ldx #0
print:
  lda message,x
  beq loop
  jsr print_char
  inx
  jmp print

loop:
  jmp loop

number: .word 1729

; Add the character in the A register to the beginning of the
; null-terminated string `message`
push_char:
  pha            ; Push new first char onto the stack
  ldy #0

char_loop:
  lda message,y  ; Get 1st char from the string and put in the X register
  tax            ; Transfer A to X
  pla            ; Pull the new char off the stack
  sta message,y  ; Add char to the string
  iny            ; Increment Y
  txa            ; Transfer X to A
  pha            ; Push char from string onto stack
  bne char_loop  ; Branch if char is not null

  pla            ; Pull the null off the stack
  sta message,y  ; Add the null to the end of the string
  rts

lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta DDRB
lcdbusy:
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #RW
  sta PORTB
  lda #(RW | E)
  sta PORTB
  lda PORTB       ; Read low nibble
  pla             ; Get high nibble off stack
  and #%00001000
  bne lcdbusy

  lda #RW
  sta PORTB
  lda #%11111111  ; Port B is output
  sta DDRB
  pla
  rts

lcd_init:
  lda #%00000011 ; 1st Set 8-bit mode
  sta PORTB
  ora #E
  sta PORTB
  and #%00001111
  sta PORTB
  lda #%00000011 ; 2nd Set 8-bit mode
  sta PORTB
  ora #E
  sta PORTB
  and #%00001111
  sta PORTB
  lda #%00000011 ; 3rd Set 8-bit mode
  sta PORTB
  ora #E
  sta PORTB
  and #%00001111
  sta PORTB 
  lda #%00000010 ; Set 4-bit mode
  sta PORTB
  ora #E
  sta PORTB
  and #%00001111
  sta PORTB
  rts

lcd_instruction:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta PORTB
  ora #E         ; Set E bit to send instruction
  sta PORTB
  eor #E         ; Clear E bit
  sta PORTB
  pla
  and #%00001111 ; Send low 4 bits
  sta PORTB
  ora #E         ; Set E bit to send instruction
  sta PORTB
  eor #E         ; Clear E bit
  sta PORTB
  rts

print_char:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #RS         ; Set RS
  sta PORTB
  ora #E          ; Set E bit to send instruction
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  pla
  and #%00001111  ; Send low 4 bits
  ora #RS         ; Set RS
  sta PORTB
  ora #E          ; Set E bit to send instruction
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  rts

  .org $fffc
  .word reset
  .word $0000
