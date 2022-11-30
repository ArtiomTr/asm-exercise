; ASCII symbols
ASCII_CR equ 0Dh ; carriage return
ASCII_LF equ 0Ah ; line feed
ASCII_TAB equ 09h ; horizontal tab
ASCII_FF equ 0Ch ; form feed
ASCII_SPACE equ 20h ; space ' '
ASCII_HELP_WORD equ 3F2Fh ; help string ("/?")
ASCII_QUOTE equ '"'
ASCII_BACKSLASH equ 5Ch
ASCII_SINGLE_QUOTE equ 27h

; Interrupt codes
INT_FUN_DISPATCH equ 21h

; Function disptach codes (interrupt 21h)
SYS_PRINT equ 09h
SYS_TERMINATE equ 4Ch
SYS_OUT equ 02h
SYS_OPEN_FILE equ 3Dh
SYS_CREATE_FILE equ 3Ch
SYS_READ_FILE equ 3Fh
SYS_WRITE_FILE equ 40h
SYS_CLOSE_FILE equ 3Eh

; Exit codes
EXIT_SUCCESS equ 0h
EXIT_FAILURE equ 1h

; File open modes
FILE_READ equ 0h

; Handy constants
CL_ARGUMENTS_START equ 81h
FILENAME_MAX_LENGTH equ 8
EXTENSION_MAX_LENGTH equ 3
BUFFER_SIZE equ 20
IDENTIFIER_BUFFER_SIZE equ 1024

; Flags
COMMENT_FLAG equ 00000001b
STRING_FLAG equ 00000010b
CHAR_FLAG equ 00000100b
NUMERIC_FLAG equ 00001000b
WORD_FLAG equ 00010000b
NUMERIC_MASK equ 11110111b
WORD_MASK equ 11101111b

; HTML generation constants
HTML_OPEN_SIZE equ 217
HTML_BODY_SIZE equ 777
HTML_CLOSE_SIZE equ 38
HTML_ROW_SIZE equ 33
HTML_NODE_OPEN_SIZE equ 16
HTML_NODE_CLOSE_SIZE equ 7

; Boolean
TRUE equ 1
FALSE equ 0

; DOS error codes
ERROR_INVALID_FUNC equ 01h
ERROR_FILE_NOT_FOUND equ 02h
ERROR_PATH_NOT_FOUND equ 03h
ERROR_TOO_MANY_OPEN_FILES equ 04h
ERROR_ACCESS_DENIED equ 05h
ERROR_INVALID_HANDLE equ 06h
ERROR_MEMORY_BLOCKS_DESTROYED equ 07h
ERROR_INSUFFICIENT_MEMORY equ 08h
ERROR_INVALID_BLOCK_ADDRESS equ 09h
ERROR_INVALID_ENVIRONMENT equ 0Ah

.model small
.stack 100h

JUMPS
LOCALS @@

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
    failed_to_open_file db "Failed to open file ", ASCII_QUOTE, '$'
    failed_to_close_file db "Failed to close file ", ASCII_QUOTE, '$'
    failed_to_read_file db "Failed to read file ", ASCII_QUOTE, '$'
    detailed_error_end db ASCII_QUOTE, ". $"
    err_invalid_func db "Invalid function number$"
    err_file_not_found db "File not found$"
    err_path_not_found db "Path not found$"
    err_too_many_open_files db "Too many open handles (no handles left)$"
    err_access_denied db "Access denied$"
    err_invalid_handle db "Invalid handle$"
    err_memory_block_destroyed db "Memory control blocks destroyed$"
    err_insufficient_memory db "Insufficient memory$"
    err_invalid_block_address db "Invalid memory block address$"
    err_invalid_environment db "Invalid environment"
    err_unknown db "Unknown error$"
    filename db FILENAME_MAX_LENGTH dup (?), '$'
    extension db EXTENSION_MAX_LENGTH dup (?), '$'
    source_filename db FILENAME_MAX_LENGTH dup (?), ?, EXTENSION_MAX_LENGTH dup (?), '$'
    desitantion_filename db FILENAME_MAX_LENGTH dup (?), ?, EXTENSION_MAX_LENGTH dup (?), '$'
    destination_file_handle dw ?
    source_file_handle dw ?
    buffer db BUFFER_SIZE dup (?), '$'
    identifier db IDENTIFIER_BUFFER_SIZE dup (?), '$'

; HTML generation template
    html_open       db "<!DOCTYPE html>", ASCII_CR, ASCII_LF, \
                       "<html lang=", ASCII_QUOTE, "en", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "<head>", ASCII_CR, ASCII_LF, \
                       "    <meta charset=", ASCII_QUOTE, "UTF-8", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "    <meta http-equiv=", ASCII_QUOTE, "X-UA-Compatible", ASCII_QUOTE, " content=", ASCII_QUOTE, "IE=edge", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "    <meta name=", ASCII_QUOTE, "viewport", ASCII_QUOTE, " content=", ASCII_QUOTE, "width=device-width, initial-scale=1.0", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "    <title>"
    html_body       db "</title>", ASCII_CR, ASCII_LF
                    db "<style>", ASCII_CR, ASCII_LF
                    db "    body {", ASCII_CR, ASCII_LF
                    db "        margin: 0;", ASCII_CR, ASCII_LF
                    db "        height: 100vh;", ASCII_CR, ASCII_LF
                    db "        background-color: #1e1e1e;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .code {", ASCII_CR, ASCII_LF
                    db "        max-width: 1000px;", ASCII_CR, ASCII_LF
                    db "        margin: 0 auto;", ASCII_CR, ASCII_LF
                    db "        width: 100%;", ASCII_CR, ASCII_LF
                    db "        height: 100%;", ASCII_CR, ASCII_LF
                    db "        overflow: auto;", ASCII_CR, ASCII_LF
                    db "        color: #d4d4d4;", ASCII_CR, ASCII_LF
                    db "        box-sizing: border-box;", ASCII_CR, ASCII_LF
                    db "        padding: 32px 16px;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .row {", ASCII_CR, ASCII_LF
                    db "        white-space: pre;", ASCII_CR, ASCII_LF
                    db "        font-family: monospace;", ASCII_CR, ASCII_LF
                    db "        min-height: 1em;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .row .c {", ASCII_CR, ASCII_LF
                    db "        color: #529955;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .row .s, .row .h {", ASCII_CR, ASCII_LF
                    db "        color: #C3916A;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .row .n {", ASCII_CR, ASCII_LF
                    db "        color: #B5CEA8;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .row .l, .i {", ASCII_CR, ASCII_LF
                    db "        color: #4B9AD6;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "    .row .k {", ASCII_CR, ASCII_LF
                    db "        color: #C584C0;", ASCII_CR, ASCII_LF
                    db "    }", ASCII_CR, ASCII_LF
                    db "</style>", ASCII_CR, ASCII_LF
                    db "</head>", ASCII_CR, ASCII_LF
                    db "<body>", ASCII_CR, ASCII_LF
                    db "    <div class=", ASCII_QUOTE, "code", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF
                    db "        <div class=", ASCII_QUOTE, "row", ASCII_QUOTE, ">"
    html_close      db "</div>", ASCII_CR, ASCII_LF, \
                       "    </div>", ASCII_CR, ASCII_LF, \
                       "</body>", ASCII_CR, ASCII_LF, \
                       "</html>", ASCII_CR, ASCII_LF
    html_row        db "</div>", ASCII_CR, ASCII_LF, \
                       "        <div class=", ASCII_QUOTE, "row", ASCII_QUOTE, ">"
    html_node_open  db "<span class=", ASCII_QUOTE
    html_node_type  db (?), ASCII_QUOTE, ">"
    html_node_close db "</span>"
; HTML escape constants
    html_escape_lt db "&lt;$"
    html_escape_gt db "&gt;$"
    html_escape_quot db "&quot;$"
    html_escape_slash db "&#47;$"
    html_escape_backslash db "&#92;$"
; Syntax highlight variables
    state_flags db 0
    should_close db FALSE
    keywords db "db dw equ byte word ptr near$"
    instructions db "aaa aad aam aas adc add and arpl "
                 db "bound bsf bsr bswap bt btc btr bts "
                 db "call cbw cdq clc cld cli clts cmc cmp cmps cwde "
                 db "daa das dec div "
                 db "enter esc "
                 db "fwait "
                 db "hlt "
                 db "idiv imul in inc ins insb insd insw int into invd invlpg iret iretd "
                 db "ja jae jb jbe jc jcxz je jecxz jg jge jl jle jmp jna jnae jnb jnbe jnc jne jnge jnl jnle jno jnp jns jnz jo jp jpe jpo js jz "
                 db "lahf lar lds lea leave les lfs lgdt lgs lidt lldt lmsw lock lods lodsb lodsd lodsw loop loope loopne loopnz loopz lsl lss ltr "
                 db "mov movs movsb movsd movsw movsx movzx msw mul "
                 db "neg nop not "
                 db "or out outs outsb outsd outsw "
                 db "pop popa popad popf popfd push pusha pushad pushf pushfd "
                 db "rcl rcr rep repe repne repnz repz ret retf retn rol ror "
                 db "sahf sal sar sbb scas scasb scasd scasw setae setb setbe setc sete setg setge setl setle setna setnae setnb setnc setne setng "
                 db "setnge setnl setnle setno setnp setns setnz seto setp setpe setpo sets setz sgdt shl shld shr shrd sidt sldt smsw stc std sti stos stosb stosd stosw str sub "
                 db "test "
                 db "verr verw "
                 db "wait wbinvd "
                 db "xchg xlat xlatb xor$"
.code

start:
    ; Swap data from data segment into extra segment
    MOV dx, ds
    mov es, dx

    ; Put data into data segment
    mov dx, @data
    mov ds, dx

    ; Parse parameters
    mov si, CL_ARGUMENTS_START
    
    ;; Parse help argument

    ;;; Erase spaces from command arguments beginning
    call trim_start
    ;;; Read first 2 non-blank characters
    mov ax, word ptr es:[si]
    ;;; Show help, if argument is "/?"
    cmp ax, ASCII_HELP_WORD
    je show_help
    
    ;; Parse file arguments (if there are any)
    call read_filename
    cmp ds:[filename], '$'
    je show_help
transform_file:
    call create_html
    
    lea dx, source_filename
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH
    
    mov dl, ASCII_CR
    mov ah, SYS_OUT
    int INT_FUN_DISPATCH

    mov dl, ASCII_LF
    mov ah, SYS_OUT
    int INT_FUN_DISPATCH

    call read_filename
    cmp ds:[filename], '$'
    jne transform_file

; When program execution ended successfully
successful_exit:
    mov al, EXIT_SUCCESS
    mov ah, SYS_TERMINATE
    int INT_FUN_DISPATCH

; Print help for command
show_help:
    ; Print help message
    lea dx, help
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH
    
    jmp successful_exit

; Skip all blank characters from command line arguments
trim_start PROC near

    trim_start_loop:
        cmp byte ptr es:[si], ASCII_SPACE
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
        cmp byte ptr es:[si], '$'
        je read_filename_invalid_character
        ; If end of string occurred, filename is completely read
        cmp byte ptr es:[si], ASCII_CR
        je read_filename_end
        ; If a space occurred, filename is completely read
        cmp byte ptr es:[si], ' '
        je read_filename_end
        ; If a dot occurred, read extension
        cmp byte ptr es:[si], '.'
        je read_filename_extension
        ; If filename length is greater than FILENAME_MAX_LENGTH, print error
        cmp ch, ah 
        jl read_filename_error
    read_filename_next:
        ; Read next character and append it to the filename
        mov al, es:[si]
        mov ds:[di], al
        inc si
        inc di
        jmp read_filename_loop
    read_filename_end:
        ; End current string
        mov al, '$'
        mov ds:[di], al
        inc di
        ; If extension is empty, set it to "asm"
        cmp cl, 1h
        je read_filename_return
        lea di, extension
        mov al, 'a'
        mov ds:[di], al
        inc di
        mov al, 's'
        mov ds:[di], al
        inc di
        mov al, 'm'
        mov ds:[di], al
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
        mov ds:[di], al
        inc di
        ; Prepare state for reading extension
        lea di, extension
        mov ah, 0
        mov ch, EXTENSION_MAX_LENGTH
        mov cl, 1h
        jmp read_filename_loop
    read_filename_invalid_character:
        lea dx, invalid_filename_error
        jmp read_filename_error_end
    read_filename_error:
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
        
        ; Begin reading filename
        lea si, filename
        ; Flag, to determine if currently copying extension
        mov ah, 0h
    construct_full_filename_loop:
        ; Take next byte
        mov al, ds:[si]
        ; If current string fully copied, try to copy next part
        cmp al, '$'
        je construct_full_filename_copy_next
        mov ds:[di], al
        inc si
        inc di
        jmp construct_full_filename_loop
    ; Copy extension
    construct_full_filename_copy_next:
        ; Check, if extension is already copied        
        cmp ah, 0h
        jne construct_full_filename_exit
        mov ah, 1h
        
        ; If not, copy extension
        lea si, extension
        mov al, '.'
        mov ds:[di], al
        inc di
        jmp construct_full_filename_loop
    ; Finalize filename
    construct_full_filename_exit:
        ; End filename
        mov al, 0
        mov ds:[di], al
        
        ; Return
        ret
construct_full_filename ENDP

write_string_to_file PROC near
        mov si, dx
        mov cx, 0
    write_string_to_file_loop:    
        cmp byte ptr ds:[si], '$'
        je write_string_to_file_dump
        inc cx
        inc si
        jmp write_string_to_file_loop
    write_string_to_file_dump:
        mov ah, SYS_WRITE_FILE
        int INT_FUN_DISPATCH
        ret

write_string_to_file ENDP

highlight_buffer PROC near
        mov cx, ax
        lea di, buffer
    highlight_buffer_loop:
        ; Match comment group
        cmp byte ptr ds:[di], ';'
        je highlight_comment_group
        cmp byte ptr ds:[di], '"'
        je highlight_string_group
        cmp byte ptr ds:[di], ASCII_SINGLE_QUOTE
        je highlight_char_group

        ; Skip numeric reading, if not suitable state
        mov al, state_flags
        and al, NUMERIC_MASK
        cmp al, 0
        jne highlight_skip_numeric

        ; If decimal, highlight
        mov al, ds:[di]
        sub al, '0'
        cmp al, 9
        jbe highlight_numeric_group

        ; If numeric group is open, check for additional characters
        cmp state_flags, NUMERIC_FLAG
        jne highlight_skip_numeric

        ; Convert character to lower case
        mov al, ds:[di]
        or al, 20h

        ; Check, if it is a-f, then treat as numeric
        sub al, 'a'
        cmp al, 'f' - 'a'
        jbe highlight_buffer_postprocess
        
        ; Check, if it is h
        cmp byte ptr ds:[di], 'h'
        je highlight_buffer_postprocess

        ; If none of the above, finalize numeric group
        jmp highlight_numeric_group_end

    ; Skip keyword check
    highlight_skip_numeric:

        mov al, state_flags
        and al, WORD_MASK
        cmp al, 0
        jne highlight_buffer_postprocess

        cmp byte ptr ds:[di], '.'
        je highlight_word_group

        mov al, ds:[di]
        or al, 20h
        sub al, 'a'
        cmp al, 'z' - 'a'
        jbe highlight_word_group

        cmp byte ptr ds:[di], '_'
        je highlight_word_group
        
        cmp state_flags, WORD_FLAG
        jne highlight_buffer_postprocess

        mov al, ds:[di]
        sub al, '0'
        cmp al, 9
        jbe highlight_word_group

        cmp byte ptr ds:[di], ':'
        je highlight_word_group

        jmp highlight_word_group_end   

    ; Do character postprocessing
    highlight_buffer_postprocess:
        ; Special character handling
        ;; EOL
        cmp byte ptr ds:[di], ASCII_CR
        je highlight_eol
        cmp byte ptr ds:[di], ASCII_LF
        je highlight_buffer_continue
        ;; Escape characters
        cmp byte ptr ds:[di], '<'
        je highlight_escape_lt
        cmp byte ptr ds:[di], '>'
        je highlight_escape_gt
        cmp byte ptr ds:[di], '"'
        je highlight_escape_quot
        cmp byte ptr ds:[di], '/'
        je highlight_escape_slash
        cmp byte ptr ds:[di], ASCII_BACKSLASH
        je highlight_escape_backslash

        push cx

        ; Copy contents to output file
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        mov dx, di
        mov cx, 1
        int INT_FUN_DISPATCH
        
        pop cx
        
        cmp should_close, TRUE
        je highlight_group_close

    highlight_buffer_continue:
        inc di
        loop highlight_buffer_loop

        ret

    ; Group matching
    highlight_word_group:
        cmp state_flags, WORD_FLAG
        je highlight_word_group_begin_skip
        lea si, identifier
    highlight_word_group_begin_skip:
        mov al, ds:[di]
        mov ds:[si], al
        inc si
        mov state_flags, WORD_FLAG
        jmp highlight_buffer_continue
    highlight_word_group_end:
        mov byte ptr ds:[si], '$'
        call pick_word_type

        mov state_flags, 0
        jmp highlight_buffer_postprocess
    highlight_numeric_group:
        cmp state_flags, NUMERIC_FLAG
        je highlight_buffer_postprocess
        
        mov state_flags, NUMERIC_FLAG
        mov html_node_type, 'n'
        jmp highlight_group
    highlight_numeric_group_end:
        mov state_flags, 0

        push cx

        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_node_close
        mov cx, HTML_NODE_CLOSE_SIZE
        int INT_FUN_DISPATCH

        pop cx

        jmp highlight_buffer_postprocess
    highlight_comment_group:
        cmp state_flags, 0
        jne highlight_buffer_postprocess

        mov state_flags, COMMENT_FLAG
        mov html_node_type, 'c'
        jmp highlight_group
    highlight_string_group:
        cmp state_flags, STRING_FLAG
        je highlight_group_mark_close
        cmp state_flags, 0
        jne highlight_buffer_postprocess
        
        mov state_flags, STRING_FLAG
        mov html_node_type, 's'
        jmp highlight_group
    highlight_char_group:
        cmp state_flags, CHAR_FLAG
        je highlight_group_mark_close
        cmp state_flags, 0
        jne highlight_buffer_postprocess
        
        mov state_flags, CHAR_FLAG
        mov html_node_type, 'h'
    highlight_group:
        push cx

        lea dx, html_node_open
        mov bx, destination_file_handle
        mov cx, HTML_NODE_OPEN_SIZE
        mov ah, SYS_WRITE_FILE
        int INT_FUN_DISPATCH

        pop cx
        jmp highlight_buffer_postprocess  
    highlight_group_mark_close:
        mov should_close, TRUE
        jmp highlight_buffer_postprocess
    highlight_group_comment_close:
        push cx
        
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_node_close
        mov cx, HTML_NODE_CLOSE_SIZE
        int INT_FUN_DISPATCH

        pop cx

        mov state_flags, 0
        jmp highlight_new_line
    highlight_group_close:
        mov should_close, FALSE
        mov state_flags, 0

        push cx

        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_node_close
        mov cx, HTML_NODE_CLOSE_SIZE
        int INT_FUN_DISPATCH

        pop cx

        jmp highlight_buffer_continue
    
    highlight_eol:
        cmp should_close, TRUE
        jne highlight_eol_skip

        mov should_close, FALSE
        mov state_flags, 0

        push cx

        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_node_close
        mov cx, HTML_NODE_CLOSE_SIZE
        int INT_FUN_DISPATCH

        pop cx
    highlight_eol_skip:    
        cmp state_flags, COMMENT_FLAG
        je highlight_group_comment_close
        jmp highlight_new_line
        
    ; Postprocessing
    highlight_new_line:
        push cx

        mov bx, destination_file_handle
        mov ah, SYS_WRITE_FILE
        lea dx, html_row
        mov cx, HTML_ROW_SIZE
        int INT_FUN_DISPATCH

        pop cx

        jmp highlight_buffer_continue
    highlight_escape_lt:
        lea dx, html_escape_lt

        jmp highlight_escape
    highlight_escape_gt:
        lea dx, html_escape_gt

        jmp highlight_escape
    highlight_escape_quot:
        lea dx, html_escape_quot

        jmp highlight_escape
    highlight_escape_slash:
        lea dx, html_escape_slash

        jmp highlight_escape
    highlight_escape_backslash:
        lea dx, html_escape_backslash

        jmp highlight_escape
    highlight_escape:
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        push cx
        call write_string_to_file
        pop cx
        jmp highlight_buffer_continue
highlight_buffer ENDP

match_keyword PROC near
        lea si, identifier
        mov al, TRUE
    @@start:
        ; Take keyword char
        mov bh, ds:[di]

        ; Check if keyword end reached
        cmp bh, ' '
        je @@keyword_end

        ; Check if keyword array end
        cmp bh, '$'
        je @@last_keyword

        ; Take identifier char
        mov ah, ds:[si]

        ; Check if identifier ended
        cmp ah, '$'
        je @@identifier_end

        ; Convert to lowercase
        or bh, 20h
        or ah, 20h

        ; Compare characters
        cmp ah, bh
        jne @@identifier_neq
    @@continue:
        inc si
        inc di
        jmp @@start
    @@identifier_neq:
        ; If identifier character is not equal to keyword, update flag
        mov al, FALSE
        jmp @@continue
    @@identifier_end:
        ; Reset identifier index
        lea si, identifier
        ; Update flag 
        mov al, FALSE
        jmp @@continue
    @@keyword_end:
        ; If identifier end not reached, skip check
        cmp byte ptr ds:[si], '$'
        jne @@keyword_skip

        ; If identifier is equal to keyword, exit
        cmp al, TRUE
        je @@exit
    @@keyword_skip:
        ; Reset identifier index
        lea si, identifier
        ; Skip space character
        inc di
        ; Reset result flag
        mov al, TRUE
        jmp @@start
    @@last_keyword:
        cmp byte ptr ds:[si], '$'
        je @@exit
        mov al, FALSE
    @@exit:
        ret 
ENDP

pick_word_type PROC near
        push cx
        push di
        lea si, identifier
        cmp byte ptr ds:[si], '.'
        je @@label

        lea di, keywords
        call match_keyword
        cmp al, TRUE
        je @@keyword

        lea di, instructions
        call match_keyword
        cmp al, TRUE
        je @@instruction

        jmp @@unknown
    @@label:
        mov html_node_type, 'l'

        jmp @@dump
    @@instruction:
        mov html_node_type, 'i'

        jmp @@dump
    @@keyword:
        mov html_node_type, 'k'

        jmp @@dump
    @@unknown:
        mov html_node_type, 'e'
    @@dump:
        lea dx, html_node_open
        mov bx, destination_file_handle
        mov cx, HTML_NODE_OPEN_SIZE
        mov ah, SYS_WRITE_FILE
        int INT_FUN_DISPATCH

        lea dx, identifier
        mov bx, destination_file_handle
        call write_string_to_file

        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_node_close
        mov cx, HTML_NODE_CLOSE_SIZE
        int INT_FUN_DISPATCH

        pop di
        pop cx
        ret
pick_word_type ENDP

print_asciiz proc near
    @@loop:
        cmp byte ptr ds:[di], 0
        je @@end

        mov ah, SYS_OUT
        mov dl, ds:[di]
        int INT_FUN_DISPATCH
        
        inc di
        
        jmp @@loop
    @@end:
        ret
print_asciiz endp

create_html PROC near
        push si
        lea di, source_filename
        call construct_full_filename

        ; open input file
        mov cx, 0
        mov bx, 0
        lea dx, source_filename
        mov al, FILE_READ
        mov ah, SYS_OPEN_FILE
        int INT_FUN_DISPATCH
        jc @@open_failure
        mov source_file_handle, ax

        ; create output file
        ;; construct filename
        lea di, extension
        mov al, 'h'
        mov ds:[di], al
        inc di
        mov al, 't'
        mov ds:[di], al
        inc di
        mov al, 'm'
        mov ds:[di], al
        
        lea di, desitantion_filename
        call construct_full_filename
        
        ;; create new file
        lea dx, desitantion_filename
        mov ah, SYS_CREATE_FILE
        mov cx, 0
        int INT_FUN_DISPATCH
        jc @@open_failure
        mov destination_file_handle, ax
        
        ;; write header
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        mov cx, HTML_OPEN_SIZE
        lea dx, html_open
        int INT_FUN_DISPATCH
    
        lea dx, source_filename
        call write_string_to_file

        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_body
        mov cx, HTML_BODY_SIZE
        int INT_FUN_DISPATCH
    @@read:
        ; Reading from input file
        mov bx, source_file_handle
        lea dx, buffer
        mov cx, BUFFER_SIZE
        mov ah, SYS_READ_FILE
        int INT_FUN_DISPATCH
        jc @@read_failure
        
        cmp ax, 0
        je @@close
        
        call highlight_buffer

        jmp @@read
    @@close:
        ; Write closing tag
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_close
        mov cx, HTML_CLOSE_SIZE
        int INT_FUN_DISPATCH

        ; Close files
        mov bx, source_file_handle
        mov ah, SYS_CLOSE_FILE
        int INT_FUN_DISPATCH
        jc @@close_failure

        mov bx, destination_file_handle
        mov ah, SYS_CLOSE_FILE
        int INT_FUN_DISPATCH
        jc @@close_failure

        pop si
        ret
    @@open_failure:
        lea cx, failed_to_open_file
        call print_file_error
    @@close_failure:
        lea cx, failed_to_close_file
        call print_file_error
    @@read_failure:
        lea cx, failed_to_read_file
        call print_file_error
create_html ENDP

print_file_error proc near
        ; Save error code
        push ax
        ; Save filename
        mov di, dx

        ; Move error message
        mov dx, cx
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        ; Print filename
        call print_asciiz

        ; Print error message closing
        lea dx, detailed_error_end
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        ; Get error code
        pop ax
        ; Print error to stdout
        call decode_error

        ; Failure exit
        mov al, EXIT_FAILURE
        mov ah, SYS_TERMINATE
        int INT_FUN_DISPATCH
print_file_error endp

decode_error proc near
        cmp al, ERROR_INVALID_FUNC
        je @@invalid_func

        cmp al, ERROR_FILE_NOT_FOUND
        je @@file_not_found

        cmp al, ERROR_PATH_NOT_FOUND
        je @@path_not_found
    
        cmp al, ERROR_TOO_MANY_OPEN_FILES
        je @@too_many_open_files
        
        cmp al, ERROR_ACCESS_DENIED
        je @@access_denied

        cmp al, ERROR_INVALID_HANDLE
        je @@invalid_handle

        cmp al, ERROR_MEMORY_BLOCKS_DESTROYED
        je @@memory_block_destroyed

        cmp al, ERROR_INSUFFICIENT_MEMORY
        je @@insufficient_memory

        cmp al, ERROR_INVALID_BLOCK_ADDRESS
        je @@invalid_block_address

        cmp al, ERROR_INVALID_ENVIRONMENT
        je @@invalid_environment


        jmp @@unknown
    @@invalid_func:
        lea dx, err_invalid_func
        jmp @@print
    @@file_not_found:
        lea dx, err_file_not_found
        jmp @@print
    @@path_not_found:
        lea dx, err_path_not_found
        jmp @@print
    @@too_many_open_files:
        lea dx, err_too_many_open_files
        jmp @@print
    @@access_denied:
        lea dx, err_access_denied
        jmp @@print
    @@invalid_handle:
        lea dx, err_invalid_handle
        jmp @@print
    @@memory_block_destroyed:
        lea dx, err_memory_block_destroyed
        jmp @@print
    @@insufficient_memory:
        lea dx, err_insufficient_memory
        jmp @@print
    @@invalid_block_address:
        lea dx, err_invalid_block_address
        jmp @@print
    @@invalid_environment:
        lea dx, err_invalid_environment
        jmp @@print
    @@unknown:
        lea dx, err_unknown
    @@print:
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH
        ret
decode_error endp

end start