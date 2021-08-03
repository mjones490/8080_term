                org     8000h

                lxi     sp,stack
                call    term_init

                mvi     a,11h
                mvi     b,form_feed
                rst     4
                ei
    
                lxi     h,prompt
                mvi     a,10h
                rst     4
        
                lxi     h,name_buff
                mvi     c,0

write_char_out:
                mvi     a,20h
                rst     4
                
                mov     a,b
                cpi     backspace
                jnz     show_char

                mov     a,c
                ora     a
                jz      write_char_out
                dcx     h
                dcr     c
                mvi     a,11h
                rst     4
                jmp     write_char_out

show_char:
                mvi     a,11h
                rst     4
                mov     a,b
                cpi     line_feed
                jz      greet

                mov     m,b
                inx     h
                inr     c
                jmp     write_char_out

greet:
                mvi     m,0
                lxi     h,greeting
                mvi     a,10h
                rst     4
                lxi     h,name_buff
                rst     4
                lxi     h,greeting_end    
                rst     4
        
                hlt

prompt:         string  "WHAT IS YOUR NAME? "
greeting        string  "HELLO, "
greeting_end    string  "!!\n"
name_buff       blk     20h

;-------------------------------------------------------------               
                mvi     b,1
pattern_loop:
                dcr     b
                jnz     pattern_loop_1
                mvi     a,11h
                mvi     b,'\n'
                rst     4
                mvi     b,04h

pattern_loop_1:                
                lxi     d,pattern+3
                lxi     h,pattern
                mvi     c,4
                mvi     a,10h
                rst     4

update_loop:
                ldax    d
                cpi     'Z'
                jnz     next_char

                mvi     a,'A'
                stax    d

                dcx     d
                dcr     c
                jz      halt
                jmp     update_loop
                
next_char:      inr     a
                stax    d
                jmp     pattern_loop

halt:           hlt


pattern:        string  "AAAA "

                blk     100h
stack:          equ     $
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
                ei
                cpi     10h                 ; decide which service to perform
                jz      print_line
                cpi     11h
                jz      print_char
                cpi     12h
                jz      scroll
                cpi     13h
                jz      clear_screen
                cpi     14h
                jz      set_cursor_location
                cpi     20h
                jz      key_read
                ret                         ; unknown service.  return.

;------------------------------------------------------------
;   Print line service.
;   In: a=10 hl=null terminated string
;------------------------------------------------------------
print_line:
                push    psw
                push    b
                push    h
print_line_loop:
                mov     a,m                 ; get current char
                inx     h                   ; advance pointer
                cpi     null_terminator     ; end of string?
                mov     b,a                 ; 
                cnz     print_char          ; print char if not
                jnz     print_line_loop     ; loop if not

                pop     h
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
                sui     >screen
                ora     l
                jz      print_char_exit
                dcx     h
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

key_read:
                push    psw
                push    h

                lxi     h,key_buffer
key_read_loop:                
                lda     key_buff_in
                mov     b,a
                lda     key_buff_out
                cmp     b
                jz      key_read_loop
                
                mov     l,a
                inr     a
                sta     key_buff_out
                mov     b,m

                pop     h
                pop     psw
                ret

                
key_buffer:     equ     9000h
key_buff_in:    byte    <key_buffer
key_buff_out    byte    <key_buffer

keyboard_int:   
                push    psw
                push    b
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
                mov     l,a
                mov     m,b
                inr     a
                sta     key_buff_in

key_int_end:
                pop     h
                pop     b
                pop     psw
                ei
                ret
