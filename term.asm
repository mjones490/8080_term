                org     8000h

                jmp     start

start:
                mvi     a,form_feed
                call    print_char

                mvi     b,50
main_loop:
                dcr     b
                jz      halt      
                lxi     h,char_line

write_loop:
                mov     a,m
                cpi     0
                jz      main_loop
                call    print_char
                inx     h
                jmp     write_loop

halt:           hlt

char_line:      string "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()-_+=/?"
;------------------------------------------------------------
; Start of terminal routines
;------------------------------------------------------------
screen:         equ     4000h
screen_size:    equ     03c0h
screen_end:     equ     screen+screen_size
screen_last_ln: equ     screen_end-28h

; Escapes
form_feed       equ     '\f'

cursor_loc:     word    screen

print_char:
                push    psw
                push    h

                cpi     form_feed
                jz      print_form_feed

                lhld    cursor_loc
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

print_char_exit:
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
