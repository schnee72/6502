PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003

E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%10111111 ; Set bit 6 on port A to input, rest to output
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

rx_wait:
  bit PORTA  ; Put PORTA.6 into overflow flag V
  bvs rx_wait  ; Loop until receive start bit

  jsr half_bit_delay

  ldx #8
read_bit:
  jsr bit_delay
  bit PORTA  ; Put PORTA.6 into V flag (overflow flag)
  bvs recv_1
  clc  ; We read a 0, put a 0 in C flag
  jmp rx_done
recv_1:
  sec  ; We read a 1, put a 1 in the carry flag C
  nop 
  nop
rx_done:
  ror  ; Rotate A register right, putting the C flag into the most significant bit
  dex 
  bne read_bit

  ; All 8 bits are now in A register
  jsr print_char

  jsr bit_delay
  jmp rx_wait

bit_delay:
  phx  ; push X register onto stack
  ldx #13
bit_delay_loop:
  dex
  bne bit_delay_loop
  plx  ; pull X register off stack
  rts

half_bit_delay:
  phx  ; push X register onto stack
  ldx #6
half_bit_delay_loop:
  dex
  bne half_bit_delay_loop
  plx  ; pull X register off stack
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
