; ASCII symbols
ASCII_CR equ 0Dh ; carriage return
ASCII_LF equ 0Ah ; line feed
ASCII_TAB equ 09h ; horizontal tab
ASCII_FF equ 0Ch ; form feed
ASCII_SPACE equ 20h ; space ' '
ASCII_HELP_WORD equ 3F2Fh ; help string ("/?")

; Interrupt codes
INT_FUN_DISPATCH equ 21h

; Function disptach codes (interrupt 21h)
SYS_PRINT equ 09h
SYS_TERMINATE equ 4Ch
SYS_OUT equ 02h
SYS_OPEN_FILE equ 3Dh

; Exit codes
EXIT_SUCCESS equ 0h
EXIT_FAILURE equ 1h

; File open modes
FILE_READ equ 0h

; Handy constants
CL_ARGUMENTS_START equ 81h
FILENAME_MAX_LENGTH equ 8
EXTENSION_MAX_LENGTH equ 3

.model small
.stack 100h

JUMPS

.data
    help db "Generates html page, displaying assmelby code (with syntax highlight)", ASCII_CR, ASCII_LF, ASCII_CR, ASCII_LF, \
            "Usage: asm2html [/?] [...files]", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "/?         - display help", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "[...files] - path to files to display.", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "             Output will be written into [filename].html files.", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "             If no files specified, input will be read from stdin.", ASCII_CR, ASCII_LF, '$' 
    filename_too_long_error db "Filename is too long - maximum allowed length is 8$"
    extension_too_long_error db "Extension is too long - maximum allowed length is 3$"
    invalid_filename_error db "Filename cannot contain dollar sign$"
    filename db FILENAME_MAX_LENGTH dup (?), '$'
    extension db EXTENSION_MAX_LENGTH dup (?), '$'
    source_filename db FILENAME_MAX_LENGTH dup (?), ?, EXTENSION_MAX_LENGTH dup (?), '$'
    destination_file_handle dw ?
    source_file_handle dw ?
.code

start:
    mov ax, @data
    mov es, ax

    ; Parse parameters
    mov si, CL_ARGUMENTS_START
    
    ;; Parse help argument

    ;;; Erase spaces from command arguments beginning
    call trim_start
    ;;; Read first 2 non-blank characters
    mov ax, word ptr ds:[si]
    ;;; Show help, if argument is "/?"
    cmp ax, ASCII_HELP_WORD
    je show_help
    
    ;; Parse file arguments (if there are any)
    call read_filename
    cmp es:[filename], '$'
    je show_help
transform_file:
    call create_html
    
    push ds
    
    mov dx, @data
    mov ds, dx
    lea dx, source_filename

    ; Print error message
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH

    pop ds

    call read_filename
    cmp es:[filename], '$'
    jne transform_file

; When program execution ended successfully
successful_exit:
    mov al, EXIT_SUCCESS
    mov ah, SYS_TERMINATE
    int INT_FUN_DISPATCH

; Print help for command
show_help:
    ; Move message to data segment
    mov dx, @data
    mov ds, dx

    ; Print help message
    lea dx, help
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH
    
    jmp successful_exit

; Skip all blank characters from command line arguments
trim_start PROC near

    trim_start_loop:
        cmp byte ptr ds:[si], ASCII_SPACE
        je trim_start_continue

        ret
    trim_start_continue:
        inc si
        jmp trim_start_loop

trim_start ENDP

; Read filename from command line arguments
read_filename PROC near
        ; Skip all whitespaces
        call trim_start
        lea di, filename
        push ax
        push cx

        mov ah, 0h
        mov cl, 0h
        mov ch, FILENAME_MAX_LENGTH
    read_filename_loop:
        inc ah

        ; If filename contains '$', it is considered invalid
        cmp byte ptr ds:[si], '$'
        je read_filename_invalid_character
        ; If end of string occurred, filename is completely read
        cmp byte ptr ds:[si], ASCII_CR
        je read_filename_end
        ; If a space occurred, filename is completely read
        cmp byte ptr ds:[si], ' '
        je read_filename_end
        ; If a dot occurred, read extension
        cmp byte ptr ds:[si], '.'
        je read_filename_extension
        ; If filename length is greater than FILENAME_MAX_LENGTH, print error
        cmp ch, ah 
        jl read_filename_error
    read_filename_next:
        ; Read next character and append it to the filename
        lodsb
        stosb
        jmp read_filename_loop
    read_filename_end:
        ; End current string
        mov al, '$'
        stosb
        ; If extension is empty, set it to "asm"
        cmp cl, 1h
        je read_filename_return
        lea di, extension
        mov al, 'a'
        stosb
        mov al, 's'
        stosb
        mov al, 'm'
        stosb
    read_filename_return:
        pop ax
        pop cx
        ret
    read_filename_extension:
        ; Check if already reading extension
        cmp cl, 1h
        je read_filename_next

        ; Increment index to skip dot
        inc si
        ; End filename string
        mov al, '$'
        stosb
        ; Prepare state for reading extension
        lea di, extension
        mov ah, 0
        mov ch, EXTENSION_MAX_LENGTH
        mov cl, 1h
        jmp read_filename_loop
    read_filename_invalid_character:
        mov dx, @data
        mov ds, dx
        lea dx, invalid_filename_error
        jmp read_filename_error_end
    read_filename_error:
        ; Move message to data segment
        mov dx, @data
        mov ds, dx

        ; Pick error message
        cmp cl, 1h
        je read_filename_extension_error
        lea dx, filename_too_long_error
        jmp read_filename_error_end
    read_filename_extension_error:
        lea dx, extension_too_long_error
    read_filename_error_end:

        ; Print error message
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        ; Failure exit
        mov al, EXIT_FAILURE
        mov ah, SYS_TERMINATE
        int INT_FUN_DISPATCH
read_filename ENDP

construct_full_filename PROC near
        lea si, filename
        mov ah, 0h
    construct_full_filename_start:
        mov cl, es:[si]
        cmp cl, '$'
        je construct_full_filename_copy_extension
        mov es:[di], cl
        inc si
        inc di
        jmp construct_full_filename_start
    construct_full_filename_copy_extension:
        lea si, extension
        cmp ah, 0h
        mov ah, 1h
        jne construct_full_filename_exit
        mov cl, '.'
        mov es:[di], cl
        inc di
        jmp construct_full_filename_start
    construct_full_filename_exit:
        ret
construct_full_filename ENDP

create_html PROC near
        lea di, source_filename
        call construct_full_filename

        ; open input filename
        ;mov dx, source_filename
        ;mov al, FILE_READ
        ;mov ah, SYS_OPEN_FILE
        ;int INT_FUN_DISPATC
    
        ret
create_html ENDP

end start