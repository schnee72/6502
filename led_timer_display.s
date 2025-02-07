PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
T1CL = $6004
T1CH = $6005
ACR = $600B
IFR = $600D
IER = $600E

value = $0200  ; 2 bytes
mod10 = $0202  ; 2 bytes
message = $0204  ; 6 bytes

ticks = $00
toggle_time = $04
lcd_time = $08

E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs
  lda #%11111111
  sta DDRA
  sta DDRB
  lda #0
  sta PORTA
  sta toggle_time
  sta lcd_time
  jsr init_timer

  jsr lcd_init
  lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001100 ; Display on; cursor off; blink off 
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #$00000001 ; Clear display
  jsr lcd_instruction

loop:
  jsr update_led
  jsr update_lcd
  jmp loop

update_led:
  sec 
  lda ticks
  sbc toggle_time
  cmp #25   ; Have 250ms elapsed?
  bcc exit_update_led
  lda #$01
  eor PORTA
  sta PORTA  ; Toggle LED
  lda ticks
  sta toggle_time
exit_update_led:
  rts

update_lcd:
  sec
  lda ticks
  sbc lcd_time
  cmp #100
  bcc skip_lcd
  sei
  lda ticks
  sta value
  lda ticks + 1
  sta value + 1
  cli
  lda #%00000001  ; Clear display
  jsr lcd_instruction
  lda #0
  sta message  ; Clear message
  jsr print_num
  lda ticks
  sta lcd_time

skip_lcd:
  rts

init_timer:
  lda #0
  sta ticks
  sta ticks + 1
  sta ticks + 2
  sta ticks + 3
  lda #%01000000
  sta ACR
  lda #$0e
  sta T1CL
  lda #$27
  sta T1CH
  lda #%11000000
  sta IER
  cli
  rts

print_num:
  ; Initialize the remainder to 0
  lda #0
  sta mod10
  sta mod10 + 1
  clc

  ldx #16  ; go through the loop 16 times
print_num_loop:
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
  bne print_num_loop
  rol value  ; shift in the last bit of the quotient

  lda mod10
  clc 
  adc #"0"  ; a = a + #"0" + carrybit
  jsr push_char

  ; if value != 0, then continue dividing
  lda value 
  ora value + 1  ; check if any bits are set
  bne print_num  ; branch if value != 0

  ldx #0
print:
  lda message,x
  beq end_print
  jsr print_char
  inx
  jmp print

end_print:
  rts

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

irq:
  bit T1CL
  inc ticks
  bne end_irq
  inc ticks + 1
  bne end_irq
  inc ticks + 2
  bne end_irq
  inc ticks + 3
end_irq:
  rti

  .org $fffc
  .word reset
  .word irq