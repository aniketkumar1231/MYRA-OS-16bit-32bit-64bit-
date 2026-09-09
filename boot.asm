[org 0x7c00]          ; Bootloader loaded at address 0x7C00 by BIOS
[bits 16]             ; 16-bit real mode

start:
    cli               ; Clear interrupts during setup
    xor ax, ax        ; AX = 0
    mov ds, ax        ; Initialize Data Segment (DS = 0)
    mov es, ax        ; Initialize Extra Segment (ES = 0)
    mov ss, ax        ; Initialize Stack Segment (SS = 0)
    mov sp, 0x7c00    ; Set Stack Pointer safely below bootloader
    sti               ; Restore interrupts

    ; Print loading message to verify execution on hardware
    mov si, msg_loading
    call print_string

    ; Add your disk reading (INT 13h) or kernel jump logic here
    
    jmp $             ; Hang for now if testing bootloader standalone

print_string:
    lodsb             ; Load next character from SI into AL
    or al, al         ; Check if null terminator (0) reached
    jz print_done
    mov ah, 0x0e      ; BIOS teletype output interrupt
    int 0x10
    jmp print_string
print_done:
    ret

msg_loading db 'Loading Myra OS Bootloader...', 0x0D, 0x0A, 0

times 510 - ($ - $$) db 0  ; Pad the rest of the 512-byte sector with zeros
dw 0xaa55                 ; Standard boot sector signature