PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
PCR = $600c
IFR = $600d
IER = $600e

kb_wptr = $0000
kb_rptr = $0001
kb_flags = $0002

char_count = $0003
first_line_count = $0004
temp_addr = $0005

RELEASE = %00000001
SHIFT   = %00000010

kb_buffer = $0200  ; 256-byte kb buffer 0200-02ff

E  = %01000000
RW = %00100000
RS = %00010000

  .org $8000

reset:
  ldx #$ff
  txs

  lda #$01
  sta PCR
  lda #$82
  sta IER
  cli

  lda #%11111111 ; Set all pins on port B to output
  sta DDRB
  lda #%00000000 ; Set all pins on port A to input
  sta DDRA

  jsr lcd_init
  lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction
  lda #%00000001 ; Clear display
  jsr lcd_instruction

  lda #$00
  sta kb_flags
  sta kb_wptr
  sta kb_rptr
  sta char_count 
  sta first_line_count

loop:
  sei
  lda kb_rptr
  cmp kb_wptr
  cli
  bne key_pressed
  jmp loop

key_pressed:
  ldx kb_rptr
  lda kb_buffer, x
  cmp #$08
  beq do_backspace
  cmp #$0a           ; enter - go to second line
  beq enter_pressed
  cmp #$1b           ; escape - clear display
  beq esc_pressed

  jsr print_char

  inc kb_rptr
  jmp loop

do_backspace:
  lda char_count
  beq check_line1
  dec char_count
  lda #$10 
  jsr lcd_instruction
  lda #' '
  jsr lcd_print_noupdate  ; erase without updating count
  lda #$10 
  jsr lcd_instruction
  jmp finish_bs

check_line1:
    lda first_line_count
    beq skip_bs         ; nothing to delete if line1 is empty

    ; Compute DDRAM address for the last character on line 1:
    ; (address = $80 + (first_line_count – 1))
    lda #$80            ; base DDRAM command for line 1
    clc
    adc first_line_count
    sec
    sbc #1
    sta temp_addr       ; save computed address

    ; Set DDRAM address to the computed value
    lda temp_addr
    jsr lcd_instruction

    ; Print a space to erase the character
    lda #' '
    jsr lcd_print_noupdate

    ; Because the LCD auto‑increments, re‑set the DDRAM address back to our target
    lda temp_addr
    jsr lcd_instruction

    ; Now update first_line_count (remove one character)
    lda first_line_count
    sec
    sbc #1
    sta first_line_count

    ; Sync global char_count with the updated first_line_count
    lda first_line_count
    sta char_count

    jmp finish_bs

finish_bs:
    inc kb_rptr
    jmp loop

skip_bs:
    inc kb_rptr
    jmp loop

enter_pressed:
  lda char_count
  sta first_line_count
  lda #%11000000 ; put cursor at position 40
  jsr lcd_instruction
  lda #0         ; reset char_count so we start at column 0 again
  sta char_count
  inc kb_rptr
  jmp loop

esc_pressed:
  lda #%00000001 ; Clear display
  jsr lcd_instruction
  lda #0         ; reset char_count so we start at column 0 again
  sta char_count
  inc kb_rptr
  jmp loop

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
  lda #%11111111  ; LCD data is output
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
  ora #E          ; Set E bit to send data
  sta PORTB
  eor #E          ; Clear E bit
  sta PORTB
  pla
  and #%00001111  ; Send low 4 bits
  ora #RS
  sta PORTB
  ora #E
  sta PORTB
  eor #E
  sta PORTB
  ; update character count
  lda char_count
  inc
  sta char_count
  cmp #16         ; have we printed 16 chars?
  bne done
  ; auto-wrap: save count for line 1 and reset for line 2
  lda char_count
  sta first_line_count  ; save first-line count (should be 16)
  lda #%11000000   ; command to move cursor to line 2
  jsr lcd_instruction
  lda #0
  sta char_count   ; start line 2 at column 0
done:
  rts

lcd_print_noupdate:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; send high 4 bits
  ora #RS        ; set RS
  sta PORTB
  ora #E         ; set E
  sta PORTB
  eor #E         ; clear E
  sta PORTB
  pla
  and #%00001111 ; send low 4 bits
  ora #RS
  sta PORTB
  ora #E
  sta PORTB
  eor #E
  sta PORTB
  rts

; IRQ vector points here
keyboard_interrupt:
  pha
  txa
  pha
  lda kb_flags
  and #RELEASE   ; check if we're releasing a key
  beq read_key   ; otherwise, read the key

  lda kb_flags
  eor #RELEASE   ; flip the releasing bit
  sta kb_flags
  lda PORTA      ; read key value that's being released
  cmp #$12       ; left shift
  beq shift_up
  cmp #$59       ; right shift
  beq shift_up
  jmp exit

shift_up:
  lda kb_flags
  eor #SHIFT  ; flip the shift bit
  sta kb_flags
  jmp exit

read_key:
  lda PORTA
  cmp #$f0        ; if releasing a key
  beq key_release ; set the releasing bit
  cmp #$12        ; left shift
  beq shift_down
  cmp #$59        ; right shift
  beq shift_down

  tax
  lda kb_flags
  and #SHIFT
  bne shifted_key

  lda keymap, x   ; map to character code
  jmp push_key

shifted_key:
  lda keymap_shifted, x   ; map to character code

push_key:
  ldx kb_wptr
  sta kb_buffer, x
  inc kb_wptr
  jmp exit

shift_down:
  lda kb_flags
  ora #SHIFT
  sta kb_flags
  jmp exit

key_release:
  lda kb_flags
  ora #RELEASE
  sta kb_flags

exit:
  pla
  tax
  pla
  rti


nmi:
  rti

  .org $fd00
keymap:
  .byte "????????????? `?" ; 00-0F
  .byte "?????q1???zsaw2?" ; 10-1F
  .byte "?cxde43?? vftr5?" ; 20-2F
  .byte "?nbhgy6???mju78?" ; 30-3F
  .byte "?,kio09??./l;p-?" ; 40-4F
  .byte "??'?[=????",$0a,"]?\??" ; 50-5F
  .byte "??????", $08, "??1?47???" ; 60-6F
  .byte "0.2568",$1b,"??+3-*9??" ; 70-7F
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF
keymap_shifted:
  .byte "????????????? ~?" ; 00-0F
  .byte "?????Q!???ZSAW@?" ; 10-1F
  .byte "?CXDE#$?? VFTR%?" ; 20-2F
  .byte "?NBHGY^???MJU&*?" ; 30-3F
  .byte "?<KIO)(??>?L:P_?" ; 40-4F
  .byte '??"?{+?????}?|??' ; 50-5F
  .byte "??????", $08, "??1?47???" ; 60-6F
  .byte "0.2568???+3-*9??" ; 70-7F
  .byte "????????????????" ; 80-8F
  .byte "????????????????" ; 90-9F
  .byte "????????????????" ; A0-AF
  .byte "????????????????" ; B0-BF
  .byte "????????????????" ; C0-CF
  .byte "????????????????" ; D0-DF
  .byte "????????????????" ; E0-EF
  .byte "????????????????" ; F0-FF

; Reset/IRQ vectors
  .org $fffa
  .word nmi
  .word reset
  .word keyboard_interrupt
