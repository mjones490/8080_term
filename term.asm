                org     8000h

                lxi     sp,stack
                call    term_init

                mvi     a,11h
                mvi     b,form_feed
                rst     4
               
                mvi     b,1
pattern_loop:
                dcr     b
                jnz     pattern_loop_1
                mvi     b,0bfh
                lxi     h,0
                mvi     a,14h
                rst     4

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
screen_size:    equ     03c0h
screen_end:     equ     screen+screen_size
screen_last_ln: equ     screen_end-28h

; Escapes
form_feed       equ     '\f'
line_feed       equ     '\n'
null_terminator equ     0
vector_loc      equ     20h

cursor_loc:     word    screen
vector_jmp:     jmp     term_service

term_init:      push    psw
                push    h
                lxi     h,vector_jmp
                mov     a,m
                sta     vector_loc
                inx     h
                mov     a,m
                sta     vector_loc+1
                inx     h
                mov     a,m
                sta     vector_loc+2
                pop     h
                pop     psw
                ret

term_service:
                cpi     10h
                jz      print_line
                cpi     11h
                jz      print_char
                cpi     12h
                jz      scroll
                cpi     13h
                jz      clear_screen
                cpi     14h
                jz      set_cursor_location
                ret

print_line:
                push    psw
                push    b
                push    h
print_line_loop:
                mov     a,m
                inx     h
                cpi     null_terminator
                mov     b,a
                cnz     print_char
                jnz     print_line_loop

                pop     h
                pop     b
                pop     psw
                ret

print_char:
                push    psw
                push    b
                push    h

                lhld    cursor_loc
                mov     a,b
                
                cpi     form_feed
                jz      print_form_feed

                cpi     line_feed
                jz      print_line_feed

                mov     m,a
                inx     h
                mvi     a,>screen_end
                cmp     h
                jnz     print_char_exit
                mvi     a,<screen_end
                cmp     l
                jnz     print_char_exit
                call    scroll
                lxi     h,screen_last_ln
                jmp     print_char_exit

print_form_feed:
                call    clear_screen
                lxi     h,screen
                jmp     print_char_exit

print_line_feed:
                mov     a,h
                sbi     >screen
                mov     h,a

                mvi     b,0
                mvi     c,16
                stc
                cmc

mod40_loop:
                mov     a,l
                ral
                mov     l,a
                mov     a,h
                ral     
                mov     h,a
                mov     a,b
                ral
                mov     b,a
                sui     28h
                jc      mod40_ignore
                mov     b,a
mod40_ignore:
                dcr     c
                jnz     mod40_loop

                lhld    cursor_loc
                mov     a,l
                sub     b
                mov     l,a
                mov     a,h
                sbi     0
                mov     h,a
                mov     a,l
                adi     28h
                mov     l,a
                mov     a,h
                aci     0
                mov     h,a

                mvi     a,>screen_end
                cmp     h
                jnz     print_char_exit
                mvi     a,<screen_end
                cmp     l
                jnz     print_char_exit
                call    scroll
                lxi     h,screen_last_ln

print_char_exit:
                shld    cursor_loc
                pop     h
                pop     b
                pop     psw
                ret

set_cursor_location:
                push    psw
                push    h
                mov     a,h
                adi     >screen
                mov     h,a
                shld    cursor_loc
                pop     h
                pop     psw
                ret
scroll:
                push    psw
                push    d
                push    h

                lxi     h,screen
                lxi     d,screen
                mvi     e,28h

scroll_loop:   
                ldax    d
                mov     m,a
                inx     h
                inx     d
                mvi     a,>screen_end
                cmp     d
                jnz     scroll_loop
                mvi     a,<screen_end
                cmp     e
                jnz     scroll_loop
                
                mvi     d,' '
                
scroll_clear_last_line:
                mov     m,d
                inx     h
                cmp     l
                jnz     scroll_clear_last_line

                pop     h
                pop     d
                pop     psw
                ret
clear_screen:
                push    psw
                push    b
                push    h
                
                lxi     h,screen
                mvi     b, ' '

clear_screen_loop:
                mov     m,b
                inx     h
                mvi     a,>screen_end
                cmp     h
                jnz     clear_screen_loop
                mvi     a,<screen_end
                cmp     l
                jnz     clear_screen_loop

                pop     h
                pop     b
                pop     psw
                ret
