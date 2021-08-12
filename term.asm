                org     8000h

                lxi     sp,stack
                call    term_init

                mvi     a,11h
                mvi     b,form_feed
                rst     4
                ei

show_menu:
                lxi     h,menu
show_menu_loop:
                mvi     a,10h
                rst     4
                mov     a,m
                ora     a
                jnz     show_menu_loop
menu_select:
                mvi     a,20h
                rst     4
                mov     a,b
                cpi     ' '
                jm      menu_select
                mvi     a,11h
                rst     4
                mov     a,b
                cpi     '1'
                jz      hex_loop
                cpi     '2'
                jz      dec_loop
                mvi     b,'\b'
                mvi     a,11h
                rst     4
                jmp     menu_select
hex_loop:
                mvi     a,10h       ; show prompt
                lxi     h,hex_prompt
                rst     4

                mvi     a,21h       ; get number string
                mvi     c,4
                lxi     h,in_buff
                rst     4

                lxi     h,in_buff
                mov     a,m
                ora     a
                jz      show_menu

                mvi     a,40h       ; convert hex string to number
                rst     4           ;  in de

                mvi     a,10h       ; output ==
                lxi     h,eq_str
                rst     4

                lxi     h,out_buff  ; convert de to decimal string
                mvi     a,42h
                rst     4
                
                mvi     a,10h       ; output converted number
                rst     4

                jmp     hex_loop

dec_loop:
                mvi     a,10h
                lxi     h,dec_prompt
                rst     4

                mvi     a,21h
                lxi     h,in_buff
                mvi     c,5
                rst     4

                mov     a,m
                ora     a
                jz      show_menu

                lxi     h,0
                push    h
                lxi     h,in_buff

dec2hex_loop:
                mov     a,m
                inx     h

                cpi     '0'
                jm      dec2hex_loop_done
                cpi     3ah
                jp      dec2hex_loop_done
                sui     '0'
                mov     b,a

                xthl
                mvi     a,19h
                cmp     h
                jm      dec2hex_overflow

                mvi     d,0ah
                mov     e,h
                mvi     a,30h
                rst     4
                mov     h,e
                mov     e,l
                mvi     l,0
                mvi     d,0ah
                mvi     a,30h
                rst     4
                dad     d
                mov     a,b
                add     l
                mov     l,a
                mov     a,h
                aci     0
                jc      dec2hex_overflow
                mov     h,a
                xthl
                jmp     dec2hex_loop
                

dec2hex_loop_done:
                mvi     a,10h
                lxi     h,eq_str
                rst     4
                
                pop     h
                call    hex_out
                
                jmp     dec_loop

hex_out:
                mov     a,h
                call    byte_out
                mov     a,l
byte_out:
                push    psw
                rrc
                rrc
                rrc
                rrc
                call    nybble_out
                pop     psw
nybble_out:
                ani     0fh
                adi     '0'
                cpi     3ah
                jm      print_nybble
                adi     07h
print_nybble:
                mov     b,a
                mvi     a,11h
                rst     4
                ret

dec2hex_overflow:
                pop     h
                lxi     h,overflow_str
                mvi     a,10h
                rst     4
                jmp     dec_loop

menu:           string  "\n\nPRESS TO\n"
                string  "  1   CONVERT HEX TO DECIMAL\n"
                string  "  2   CONVERT DECIMAL TO HEX\n\n"
                string  "CHOICE: "
                byte    0
hex_prompt:     string  "\nENTER HEX: "
dec_prompt:     string  "\nENTER DECIMAL: "
eq_str:         string  " == "
overflow_str:   string  " OVERFLOW"
out_buff:       blk     6
in_buff:        blk     6

                blk     100h
stack:          equ     $

str_len:
                push    psw
                push    h
                mvi     c,0
str_len_loop:
                mov     a,m
                ora     a
                jz      str_len_end
                inr     c
                inx     h
                jmp     str_len_loop

str_len_end:    
                pop     h
                pop     psw
                ret
;------------------------------------------------------------
; Start of terminal routines
;------------------------------------------------------------
screen:         equ     4000h
screen_rows:    equ     18h
screen_cols:    equ     28h
screen_size:    equ     screen_rows*screen_cols
screen_end:     equ     screen+screen_size
screen_last_ln: equ     screen_end-screen_cols
cursor_char:    equ     1fh
pattern_tab:    equ     4400h

key_port:       equ     10h
keystat_port:   equ     13h
keyint_vector:  equ     0030h

cursor_pat:     byte    00h,7eh,42h,42h,42h,42h,42h,7eh

; Escapes
form_feed       equ     '\f'
line_feed       equ     '\n'
backspace       equ     '\b'

null_terminator equ     0

vector_loc      equ     20h             ; address of reset 4 vector

cursor_loc:     word    screen          ; current address of cursor
vector_jmp:     jmp     term_service    ; reset vector code

term_init:      push    psw         
                push    b
                push    d
                push    h

                lxi     h,vector_jmp    ; load terminal service vector
                mov     a,m
                sta     vector_loc
                inx     h
                mov     a,m
                sta     vector_loc+1
                inx     h
                mov     a,m
                sta     vector_loc+2

                lxi     d,cursor_pat     ; load cursor pattern
                lxi     h,pattern_tab+cursor_char*8
                mvi     c,8
 load_pat_loop:
                ldax    d
                mov     m,a
                inx     d
                inx     h
                dcr     c
                jnz     load_pat_loop

                lxi     h,keyint_vector   ; load keyboard interrupt vector
                mvi     m,0c3h
                inx     h
                mvi     m,<keyboard_int
                inx     h
                mvi     m,>keyboard_int
                mvi     a,02h
                out     key_port

                pop     h
                pop     d
                pop     b
                pop     psw
                ret

term_service:
                push    h
                push    psw
                push    d

                ora     a           ; clear carry
                ral                 ; get service offset
                mov     e,a         ; into de
                mvi     a,0         ;
                ral                 ;
                mov     d,a         ;

                lxi     h,service_table
                dad     d           ; add service offset
                mov     e,m         ; get service vector    
                inx     h           ; into de
                mov     d,m 
                xchg                ; move to hl

                pop     d
                pop     psw
                xthl                ; exchange with top of stack
                ei
service_ret:    ret                 ; "return" to called service.

;------------------------------------------------------------
;   Print line service.
;   In: a=10 hl=null terminated string
;   Out: hl=one char past terminator
;------------------------------------------------------------
print_line:
                push    psw
                push    b
print_line_loop:
                mov     a,m                 ; get current char
                inx     h                   ; advance pointer
                cpi     null_terminator     ; end of string?
                mov     b,a                 ; 
                cnz     print_char          ; print char if not
                jnz     print_line_loop     ; loop if not

                pop     b
                pop     psw
                ret

;------------------------------------------------------------
;   Print char service
;   In: a=11 b=char to print
;------------------------------------------------------------
print_char:
                push    psw
                push    b
                push    h

                lhld    cursor_loc          ; get current cursor location
                mvi     m,' '
                mov     a,b
                
                cpi     form_feed           ; is it a form feed?
                jz      print_form_feed

                cpi     line_feed           ; is it a line feed?
                jz      print_line_feed

                cpi     backspace           ; is it a backspace?
                jz      print_backspace     

                mov     m,a                 ; put char on screen
                inx     h                   ; next location on screen
                mvi     a,>screen_end       ; is it past end of screen?
                cmp     h
                jnz     print_char_exit
                mvi     a,<screen_end
                cmp     l
                jnz     print_char_exit
                call    scroll              ; yes, scroll screen
                lxi     h,screen_last_ln    ; move back to last line
                jmp     print_char_exit     ; exit

print_form_feed:
                call    clear_screen        ; clear screen
                lxi     h,screen            ; reset location
                jmp     print_char_exit     ; exit

print_backspace:
                mov     a,h
                sui     >screen             ; subtract screen offset
                ora     l                   ; 
                jz      print_char_exit     ; exit if already at beginning
                dcx     h                   ; move back one space
                jmp     print_char_exit

print_line_feed:
                mov     a,h                 ; get offset from top of screen
                sbi     >screen
                mov     h,a

                mvi     b,0                 ; clear remainder
                mvi     c,16                ; loop 16 times
                stc                         ; clear carry
                cmc

mod40_loop:
                mov     a,l                 ; shift carry into l
                ral
                mov     l,a
                mov     a,h                 ; shift carry into h
                ral     
                mov     h,a
                mov     a,b                 ; shift carry into b
                ral
                mov     b,a                 
                sui     screen_cols         ; subtract divisor
                jc      mod40_ignore        ; was there a borrow?
                mov     b,a                 ; preserve if not
mod40_ignore:
                dcr     c                   ; loop until done
                jnz     mod40_loop

                lhld    cursor_loc          ; get current location
                mov     a,l                 ; subract column number from location
                sub     b                   ;  to go to start of current row
                mov     l,a
                mov     a,h
                sbi     0
                mov     h,a
                mov     a,l                
                adi     screen_cols         ; add one row
                mov     l,a
                mov     a,h
                aci     0
                mov     h,a

check_screen_location
                mvi     a,>screen_end       ; past screen end?
                cmp     h
                jnz     print_char_exit
                mvi     a,<screen_end
                cmp     l
                jnz     print_char_exit
                call    scroll              ; yes.  scroll screen
                lxi     h,screen_last_ln    ; move back to last line

print_char_exit:
                mvi     m,cursor_char
                shld    cursor_loc          ; save cursor location
                pop     h
                pop     b
                pop     psw
                ret
;------------------------------------------------------------
;  Set cursor location
;  In: a=14 hl=offset of cursor in bytes from top left
;------------------------------------------------------------
set_cursor_location:
                push    psw
                push    b
                push    h

                mov     a,h             ; add screen offset to high byte
                adi     >screen
                mov     h,a

                jmp     check_screen_location
;------------------------------------------------------------
;  Scroll the screen one line
;  In: a=12
;------------------------------------------------------------
scroll:
                push    psw
                push    b
                push    d
                push    h

                lxi     h,screen        ; load screen location
                lxi     d,screen        ;
                mvi     e,screen_cols   ; set low byte to next row

                lxi     b,screen_size-screen_cols
scroll_loop:   
                ldax    d               ; get char from next line
                mov     m,a             ; put it on prev line
                inx     h               ; advance pointers
                inx     d
                dcx     b               ; decrement counter
                mov     a,b             ; check if done
                ora     c
                jnz     scroll_loop     ; loop if not
                
                mvi     c,screen_cols
                mvi     a,' '

scroll_clear_last_line:
                mov     m,a             ; write space to last line
                inx     h               ; advance ptr
                dcr     c
                jnz     scroll_clear_last_line

                pop     h
                pop     d
                pop     b
                pop     psw
                ret

;------------------------------------------------------------
;  Clear screen
;  In: a=13
;------------------------------------------------------------
clear_screen:
                push    psw
                push    b
                push    d
                push    h
                
                lxi     h,screen            ; load screen location
                lxi     b,screen_size       ; load screen size
                mvi     d, ' '              ; clear char

clear_screen_loop:
                mov     m,d                 ; write space to screen
                inx     h                   ; next screen location
                dcx     b                   ; decrement counter
                mov     a,b                 ; check if done
                ora     c                   
                jnz     clear_screen_loop   ; loop if not

                pop     h
                pop     d
                pop     b
                pop     psw
                ret

;------------------------------------------------------------
; Read single key from buffer
; In: a=20
; Out: b=key read
;------------------------------------------------------------
key_read:
                push    psw
                push    d
                push    h

                lxi     h,key_buffer
key_read_loop:                
                lda     key_buff_in
                mov     b,a
                lda     key_buff_out
                cmp     b
                jz      key_read_loop
                
                mov     e,a
                mvi     d,0
                dad     d
                inr     a
                sta     key_buff_out
                mov     b,m

                pop     h
                pop     d
                pop     psw
                ret

input:
                push    psw
                push    b
                push    d
                push    h
                
                mov     d,c
                mvi     c,0
input_loop:
                call    key_read

                mov     a,b
                cpi     backspace
                jz      input_backspace

                cpi     line_feed
                jz      input_done

                mov     a,c
                cmp     d
                jz      input_loop

                call    print_char
                mov     m,b
                inx     h
                inr     c
                jmp     input_loop

input_backspace:
                mov     a,c
                ora     a
                jz      input_loop
                dcx     h
                dcr     c
                call    print_char
                jmp     input_loop

input_done:
                mvi     m,0
                pop     h
                pop     d
                pop     b
                pop     psw
                ret

                
key_buff_in:    byte    <key_buffer
key_buff_out    byte    <key_buffer

keyboard_int:   
                push    psw
                push    b
                push    d
                push    h
                in      keystat_port
                ora     a
                jz      key_int_end
                in      key_port
                ora     a
                jnz     check_key
                in      key_port+1
                
                cpi     backspace
                jz      buffer_key

                cpi     0dh
                jnz     key_int_end
                mvi     a,line_feed
                jmp     buffer_key

check_key:
                cpi     20h
                jm      key_int_end
                
                cpi     'z'
                jp      key_int_end
                cpi     'a'
                jm      buffer_key
                ani     5fh
buffer_key:
                lxi     h,key_buffer
                mov     b,a
                lda     key_buff_in
                mov     e,a
                mvi     d,0
                dad     d
                mov     m,b
                inr     a
                sta     key_buff_in

key_int_end:
                pop     h
                pop     d
                pop     b
                pop     psw
                ei
                ret

;------------------------------------------------------------
; Multiply
; In: a=30h  d=multiplican e=multiplier
; Out: de=product
;------------------------------------------------------------
multiply:
                push    psw
                push    b
                push    h

                mov     h,d
                mvi     d,0
                mvi     l,0
                mvi     c,8h
                xra     a
mult_loop:   
                mov     a,l
                ral
                mov     l,a
                mov     a,h
                ral     
                mov     h,a
                jnc     mult_next
                dad     d
mult_next:
                dcr     c
                jnz     mult_loop
                
                mov     d,h
                mov     e,l

                pop     h
                pop     b
                pop     psw
                ret

;------------------------------------------------------------
; Divide
; In: a=31  b=divisor  de=dividend
; Out: b=remainder  de=quotient
;------------------------------------------------------------
divide:
                push    psw
                push    h
                push    b

                mvi     c,10h
                xra     a
                mov     h,a
                mov     l,a
div_loop:
                mov     a,e
                ral
                mov     e,a
                mov     a,d
                ral
                mov     d,a
                mov     a,l
                ral     
                mov     l,a
                mov     a,h
                ral
                mov     h,a

                push    b
                mov     a,l
                sub     b
                mov     c,a
                mov     a,h
                sbi     0
                cmc
                jnc     div_next

                mov     h,a
                mov     l,c
    
div_next:
                pop     b
                dcr     c
                jnz     div_loop

                mov     a,e
                ral
                mov     e,a
                mov     a,d
                ral 
                mov     d,a

                pop     b
                mov     b,l
                pop     h
                pop     psw
                ret

;------------------------------------------------------------
; String to hex
; In: a=40h hl=hex string
; Out: de=hex result
;------------------------------------------------------------
str2hex:
                push    psw
                push    b
                push    h

                mvi     d,0
                mvi     e,0
                
str2hex_loop:
                mov     a,m
                inx     h
                sui     '0'
                jm      str2hex_done
                cpi     0ah
                jm      str2hex_store
                sui     07h
                cpi     10h
                jp      str2hex_done
str2hex_store:
                mov     b,a
                ora     a
                mvi     c,4
str2hex_ral:
                mov     a,e
                ral
                mov     e,a
                mov     a,d
                ral
                mov     d,a
                dcr     c
                jnz     str2hex_ral
                
                mov     a,e
                ora     b
                mov     e,a
                jmp     str2hex_loop
str2hex_done:
                pop     h
                pop     b
                pop     psw
                ret

;------------------------------------------------------------
; Format word to decimal string
; In: a=42h  de=number to convert
; Out: hl=output buffer
;------------------------------------------------------------
word2dec:
                push    psw
                push    b
                push    d

                mvi     m,0
word2dec_loop:
                mvi     b,10
                call    divide

                mvi     a,'0'       ; ascii adjust char
                add     b
                mov     b,a
                call    push_char

                mov     a,d         ; loop until dividend is 0
                ora     e
                jnz     word2dec_loop

                pop     d
                pop     b
                pop     psw
                ret

;------------------------------------------------------------
; Push character into beginning of string
; In: a=41h  b=character to push  hl=address of string
;------------------------------------------------------------
push_char:      
                push    psw
                push    b
                push    h

push_char_loop:
                mov     a,b         ; push char
                mov     b,m
                mov     m,a
                inx     h
                ora     a
                jnz     push_char_loop

                pop     h
                pop     b
                pop     psw
                ret

                ;*** END OF ROUTINES ***
key_buffer:     blk     100h

service_table:
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                ; Terminal output routines
                word    print_line              ; 10h
                word    print_char              ; 11h
                word    scroll                  ; 12h
                word    clear_screen            ; 13h
                word    set_cursor_location     ; 14h
                word    service_ret 
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                ; Terminal input routines
                word    key_read                ; 20h
                word    input                   ; 21h
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                ; Math routines
                word    multiply                ; 30h
                word    divide                  ; 31h
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                ; String routines
                word    str2hex                 ; 40h
                word    push_char               ; 41h
                word    word2dec                ; 42h
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret

                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
                word    service_ret
