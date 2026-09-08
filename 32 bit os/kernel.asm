[org 0x8000]
[bits 16]

start:
    call clear_screen
    mov si, WELCOME_MSG
    call print_string

login_loop:
    mov si, PASS_PROMPT
    call print_string
    
    mov di, password_buffer
    call read_string_hidden     
    
    mov si, password_buffer
    mov di, CORRECT_PASS
    call strcmp
    jc login_success

    mov si, PASS_ERR
    call print_string
    jmp login_loop

login_success:
    mov si, LOGIN_OK_MSG
    call print_string

main_loop:
    mov si, PROMPT
    call print_string
    
    call read_string
    
    mov si, input_buffer
    mov di, CMD_INFO
    call strcmp
    jc do_info

    mov si, input_buffer
    mov di, CMD_CLEAR
    call strcmp
    jc do_clear
    
    mov si, input_buffer
    mov di, CMD_HELP
    call strcmp
    jc do_help
    
    mov si, input_buffer
    mov di, CMD_CAT
    call strcmp
    jc do_cat

    mov si, input_buffer
    mov di, CMD_CPUID
    call strcmp
    jc do_cpuid

    mov si, input_buffer
    mov di, CMD_PMODE
    call strcmp
    jc do_pmode
    
    mov si, input_buffer
    mov di, CMD_REBOOT
    call strcmp
    jc do_reboot

    mov si, ERR_MSG
    call print_string
    jmp main_loop

do_info:
    mov si, INFO_MSG
    call print_string
    jmp main_loop

do_clear:
    call clear_screen
    jmp main_loop
    
do_help:
    mov si, HELP_MSG
    call print_string
    jmp main_loop

do_cat:
    mov si, FILE_DATA
    call print_string
    jmp main_loop

do_cpuid:
    mov eax, 0
    cpuid
    mov [cpu_vendor + 0], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0

    mov si, CPU_MSG
    call print_string
    mov si, cpu_vendor
    call print_string
    mov si, NEWLINE
    call print_string
    jmp main_loop

do_pmode:
    cli                     
    lgdt [gdt_descriptor]   

    mov eax, cr0
    or eax, 0x1             
    mov cr0, eax            

    jmp 0x08:pmode_32bit
    
do_reboot:
    jmp 0xFFFF:0x0000

; --- 16-Bit Helper Functions ---

clear_screen:
    mov ah, 0x06
    mov al, 0x00
    mov bh, 0x0A                
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000
    int 0x10
    ret

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

read_string:
    mov di, input_buffer
.loop:
    mov ah, 0x00
    int 0x16                    
    cmp al, 0x0d                
    je .done
    cmp al, 0x08                
    je .backspace
    
    stosb
    mov ah, 0x0e
    int 0x10
    jmp .loop

.backspace:
    cmp di, input_buffer
    je .loop
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.done:
    mov byte [di], 0
    mov si, NEWLINE
    call print_string
    ret

read_string_hidden:
    mov di, password_buffer
.loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0d
    je .done
    cmp al, 0x08
    je .backspace
    
    stosb
    mov ah, 0x0e
    mov al, '*'                 
    int 0x10
    jmp .loop

.backspace:
    cmp di, password_buffer
    je .loop
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.done:
    mov byte [di], 0
    mov si, NEWLINE
    call print_string
    ret

strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .notequal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.notequal:
    clc
    pop di
    pop si
    ret
.equal:
    stc
    pop di
    pop si
    ret


; ==========================================
; 32-BIT PROTECTED MODE SECTION
; ==========================================
[bits 32]
pmode_32bit:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000            

    call clear_screen_32

    mov word [cursor_row], 0
    mov byte [cursor_col], 0
    mov byte [shift_state], 0
    mov byte [caps_state], 0
    mov byte [input_idx_32], 0

    mov esi, pmode_msg
    call print_string_32

    mov esi, pmode_prompt
    call print_string_32

flush_kbd_buffer:
    in al, 0x64
    test al, 0x01
    jz keyboard_poll_loop
    in al, 0x60
    jmp flush_kbd_buffer

keyboard_poll_loop:
    in al, 0x64                 ; Read status
    test al, 0x01               ; Buffer full?
    jz keyboard_poll_loop

    in al, 0x60                 ; Read raw scancode

    ; Handle Shift press / release
    cmp al, 0x2A                ; Left Shift Press
    je .shift_down
    cmp al, 0x36                ; Right Shift Press
    je .shift_down
    cmp al, 0xAA                ; Left Shift Release
    je .shift_up
    cmp al, 0xB6                ; Right Shift Release
    je .shift_up

    ; Handle Caps Lock press
    cmp al, 0x3A                ; Caps Lock Press
    je .toggle_caps

    test al, 0x80               ; Ignore remaining break codes
    jnz keyboard_poll_loop

    cmp al, 0x1C                ; Enter key
    je .handle_enter

    cmp al, 0x0E                ; Backspace key
    je .handle_backspace

    cmp al, 0x3B                ; Bounds check Set 1 map
    jge keyboard_poll_loop

    ; Translate Set 1 scancode
    movzx ebx, al
    mov al, [scancode_set1_map + ebx]
    test al, al
    jz keyboard_poll_loop

    ; Check if key is a lowercase letter
    cmp al, 'a'
    jl .not_letter
    cmp al, 'z'
    jg .not_letter

    ; Letter casing = shift_state XOR caps_state
    mov cl, [shift_state]
    xor cl, [caps_state]
    cmp cl, 1
    je .use_shift
    jmp .got_char

.not_letter:
    cmp byte [shift_state], 1
    je .use_shift
    jmp .got_char

.use_shift:
    mov al, [scancode_set1_shift_map + ebx]

.got_char:
    ; Store in 32-bit input buffer if room remains
    cmp byte [input_idx_32], 63
    jge keyboard_poll_loop

    movzx ebx, byte [input_idx_32]
    mov [input_buffer_32 + ebx], al
    inc byte [input_idx_32]

    call print_char_32
    jmp keyboard_poll_loop

.shift_down:
    mov byte [shift_state], 1
    jmp keyboard_poll_loop

.shift_up:
    mov byte [shift_state], 0
    jmp keyboard_poll_loop

.toggle_caps:
    xor byte [caps_state], 1
    jmp keyboard_poll_loop

.handle_enter:
    ; Null-terminate current command buffer
    movzx ebx, byte [input_idx_32]
    mov byte [input_buffer_32 + ebx], 0

    mov byte [cursor_col], 0
    inc word [cursor_row]
    cmp word [cursor_row], 25
    jl .enter_no_scroll
    mov word [cursor_row], 24
.enter_no_scroll:

    ; If user pressed Enter on an empty line, skip parsing
    cmp byte [input_idx_32], 0
    je .prompt_again

    ; Match Command: "clear"
    mov esi, input_buffer_32
    mov edi, CMD_CLEAR
    call strcmp_32
    jc .exec_clear

    ; Match Command: "help"
    mov esi, input_buffer_32
    mov edi, CMD_HELP
    call strcmp_32
    jc .exec_help

    ; Match Command: "reboot"
    mov esi, input_buffer_32
    mov edi, CMD_REBOOT
    call strcmp_32
    jc .exec_reboot

    ; Unknown Command
    mov esi, pmode_err_msg
    call print_string_32
    jmp .prompt_again

.exec_clear:
    call clear_screen_32
    jmp .prompt_again

.exec_help:
    mov esi, pmode_help_msg
    call print_string_32
    jmp .prompt_again

.exec_reboot:
    mov al, 0xFE                ; Reset CPU via 8042 Keyboard Controller
    out 0x64, al
    jmp $

.prompt_again:
    mov byte [input_idx_32], 0
    mov esi, pmode_prompt
    call print_string_32
    jmp keyboard_poll_loop

.handle_backspace:
    cmp byte [input_idx_32], 0
    je keyboard_poll_loop

    dec byte [input_idx_32]
    dec byte [cursor_col]

    push edi
    push eax
    mov edi, 0xB8000
    movzx eax, word [cursor_row]
    imul eax, eax, 160
    add edi, eax
    movzx eax, byte [cursor_col]
    shl eax, 1
    add edi, eax
    mov word [edi], 0x0A20
    pop eax
    pop edi
    jmp keyboard_poll_loop

; --- 32-Bit Helper Functions ---

print_string_32:
    push edi
    push esi
    push eax
.loop_32:
    lodsb
    test al, al
    jz .done_32
    cmp al, 13                  
    je .newline_32

    call print_char_32
    jmp .loop_32

.newline_32:
    mov byte [cursor_col], 0
    inc word [cursor_row]
    jmp .loop_32

.done_32:
    pop eax
    pop esi
    pop edi
    ret

print_char_32:
    push edi
    push eax
    push ebx

    mov bl, al                  

    mov edi, 0xB8000
    movzx eax, word [cursor_row]
    imul eax, eax, 160
    add edi, eax
    movzx eax, byte [cursor_col]
    shl eax, 1
    add edi, eax
    
    mov ah, 0x0A                ; Color: Green on Black
    mov al, bl                  
    mov [edi], ax               

    inc byte [cursor_col]
    cmp byte [cursor_col], 80
    jge .wrap_char
    
    pop ebx
    pop eax
    pop edi
    ret

.wrap_char:
    mov byte [cursor_col], 0
    inc word [cursor_row]
    pop ebx
    pop eax
    pop edi
    ret

clear_screen_32:
    mov edi, 0xB8000
    mov ecx, 2000               
    mov ax, 0x0A20              
    rep stosw                   
    mov word [cursor_row], 0
    mov byte [cursor_col], 0
    ret

strcmp_32:
    push esi
    push edi
.loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .not_equal
    test al, al
    jz .equal
    inc esi
    inc edi
    jmp .loop
.not_equal:
    clc
    pop edi
    pop esi
    ret
.equal:
    stc
    pop edi
    pop esi
    ret

; --- PS/2 Scancode Maps ---
scancode_set1_map:
    db 0,  27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8, 9
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13, 0, 'a', 's'
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 39, 96, 0, 92, 'z', 'x', 'c', 'v'
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0

scancode_set1_shift_map:
    db 0,  27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 8, 9
    db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 13, 0, 'A', 'S'
    db 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', 34, '~', 0, '|', 'Z', 'X', 'C', 'V'
    db 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0

; --- Global Descriptor Table (GDT) ---
[bits 16]
gdt_start:
    dd 0x0                      
    dd 0x0

gdt_code:
    dw 0xffff                   
    dw 0x0                      
    db 0x0                      
    db 10011010b                
    db 11001111b                
    db 0x0                      

gdt_data:
    dw 0xffff                   
    dw 0x0                      
    db 0x0                      
    db 10010010b                
    db 11001111b                
    db 0x0                      

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  
    dd gdt_start                

; --- Data Section ---

WELCOME_MSG:   db '=== *MYRA* === SECURE 16-BIT KERNEL v2.0 ===', 13, 10, 0
PASS_PROMPT:   db 'Enter Password (root): ', 0
CORRECT_PASS:  db 'root', 0
PASS_ERR:      db 'Access Denied. Try again.', 13, 10, 0
LOGIN_OK_MSG:  db 'Access Granted. Welcome, BOSS!', 13, 10, 0

PROMPT:        db 'OS> ', 0
NEWLINE:       db 13, 10, 0
INFO_MSG:      db 'Kernel v2.0 - Protected Real Mode Session', 13, 10, 0
HELP_MSG:      db 'Commands: info, clear, cat, cpuid, pmode, help, reboot', 13, 10, 0
FILE_DATA:     db 'Sector Data: System integrity 100% operational.', 13, 10, 0
CPU_MSG:       db 'CPU Vendor: ', 0
ERR_MSG:       db 'Unknown command. Type help.', 13, 10, 0

CMD_INFO:      db 'info', 0
CMD_CLEAR:     db 'clear', 0
CMD_HELP:      db 'help', 0
CMD_CAT:       db 'cat', 0
CMD_CPUID:     db 'cpuid', 0
CMD_PMODE:     db 'pmode', 0
CMD_REBOOT:    db 'reboot', 0

pmode_msg:       db 'MYRA OS [32-BIT PROTECTED MODE]: Keyboard active.', 13, 0
pmode_prompt:    db 'PMODE32> ', 0
pmode_help_msg:  db 'PMODE Commands: clear, help, reboot', 13, 0
pmode_err_msg:   db 'Unknown 32-bit command.', 13, 0

cursor_row:      dw 0
cursor_col:      db 0
shift_state:     db 0
caps_state:      db 0

input_idx_32:    db 0
input_buffer_32: times 64 db 0

cpu_vendor:      times 16 db 0
password_buffer: times 32 db 0
input_buffer:    times 64 db 0