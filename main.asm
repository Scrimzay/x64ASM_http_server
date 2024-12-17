; this was converted from an arm http server
; some parts will have long comments, theyre just for me to save into my brain
default rel
global main
extern GetStdHandle
extern WriteConsoleA
extern WSAStartup    ; Correct function name
extern WSACleanup    ; Correct function name
extern socket        ; Use standard socket function names
extern bind
extern listen
extern accept
extern recv
extern send
extern closesocket   ; Correct function name
extern htons
extern ExitProcess

section .data
    start_msg db "Server starting on port 6969...", 0
    listen_msg db "Server is listening...", 0
    close_msg db "Connection closed", 0
    error_msg db "Error occurred!", 0

    mom_response db "HTTP/1.1 413 Entity Too Large", 13, 10
                 db "Content-Type: text/plain", 13, 10
                 db "Content-Length: 43", 13, 10, 13, 10
                 db "Honey, mama is busy right now. Ask your dad."
    mom_response_len equ $ - mom_response

    dad_response db "HTTP/1.1 410 Gone", 13, 10
                 db "Content-Type: text/plain", 13, 10
                 db "Content-Length: 36", 13, 10, 13, 10
                 db "I'll buy some milk and get back soon"
    dad_response_len equ $ - dad_response

    default_response db "HTTP/1.1 405 Method Not Allowed", 13, 10
                     db "Content-Type: text/plain", 13, 10
                     db "Content-Length: 29", 13, 10
                     db "Allow: GET", 13, 10, 13, 10
                     db "Method is not allowed for URL"
    default_response_len equ $ - default_response

    mom_url db "GET /urmom", 0
    dad_url db "GET /urdad", 0

    ; Winsock init
    wsa_data times 400 db 0 ; WSAData structure
    ws_version dw 0x0202 ; Version 2.2

    ; wsa_data is a buffer that holds 400 bytes to hold winsock init data (WSAStartup fills this)

    ; Socket params
    sin_family dw 2 ; AF_INET
    sin_port dw 0x391B ; Port 6969 in network byte order (htons(6969))
    sin_addr dd 0 ; INADDR_ANY

    ; sin_family is the address family, 2, which specifies IPv4
    ; sin_port is the htons converted port in network byte order (the C program to find this will be at the bottom)
    ; sin_addr is 0 (INADDR_ANY) which allows connections form any IPv4 address

section .bss
    socket_fd resq 1
    client_socket resq 1
    ;these store file descriptors for the server and client sockets

    request_buffer resb 1024
    ; a buffer of 1024 bytes to hold the incoming http request

    bytes_recieved resq 1
    ; stores the number of bytes returned by recv

    console_written resq 1

    sockaddr resb 16 ; sockaddr_in struct
    ; a reserved block of 16 bytes to represent the sockaddr_in structure

section .text
main:
    ; Ensures proper stack alignent for function calls
    sub rsp, 40

    ; Init Winsock
    mov rcx, ws_version
    mov rdx, wsa_data
    call WSAStartup
    test rax, rax
    jnz error_exit

    ; Create socket
    mov rcx, 2 ; AF_INET
    mov rdx, 1 ; SOCK_STREAM
    mov r8, 0 ; Protocol
    ; the above creates a TCP socket

    call socket
    mov [socket_fd], rax
    ; the above is a file descriptor stored in socket_fd

    cmp rax, -1
    je error_exit

    ; Prepare sockaddr_in
    mov word [sockaddr], 2 ; sin_family = AF_INET
    mov word [sockaddr+2], 0x391B ; sin_port = htons(6969)
    mov dword [sockaddr+4], 0 ; sin_addr = INADDR_ANY

    ; Prepares the sockaddr_in struct with port 6969 and binds it to the socket
    mov rcx, [socket_fd]
    mov rdx, sockaddr
    mov r8, 16 ; sizeof(sockaddr_in)
    call bind
    test rax, rax
    jnz error_exit

    ; listen
    mov rcx, [socket_fd]
    mov rdx, 5 ; backlog
    call listen
    test rax, rax
    jnz error_exit

request_loop:
    ; Accept connection
    mov rcx, [socket_fd]
    mov rdx, 0 ; NULL for address
    mov r8, 0 ; NULL for address length
    call accept ; Waits for a client connection and returns a file descriptor (client_socket)
    mov [client_socket], rax
    cmp rax, -1
    je request_loop

    ; Recieve request
    mov rcx, [client_socket]
    mov rdx, request_buffer
    mov r8, 1024
    mov r9, 0 ; Flags
    call recv ; Reads the HTTP request into request_buffer
    cmp rax, 0 ; Check if data is recieved
    jle close_connection ; If <= 0, close connection
    mov [bytes_recieved], rax

    ; Check for /urmom or /urdad
    mov rdi, request_buffer
    mov rsi, mom_url
    call strstr
    test rax, rax
    jnz load_mom_response

    mov rdi, request_buffer
    mov rsi, dad_url
    call strstr
    test rax, rax
    jnz load_dad_response

    ; Default response if no match
    mov rax, default_response
    mov rbx, default_response_len
    jmp send_response

load_mom_response:
    mov rax, mom_response
    mov rbx, mom_response_len
    jmp send_response

load_dad_response:
    mov rax, dad_response
    mov rbx, dad_response_len
    jmp send_response

send_response:
    ; Send response
    mov rcx, [client_socket]
    mov rdx, rax ; Response buffer
    mov r8, rbx ; response length
    mov r9, 0 ; Flags
    call send

    ; Close client socket
    mov rcx, [client_socket]
    call closesocket

    jmp request_loop

; Custom strstr implementation (simplified) to find a substring in a string
; Steps: 1. Loops through each character of the main string (rdi)
; 2. For each position, compares the substring (rsi) to the main string character by character
; 3. If a mismatch occurs, resets and increments the main string pointer
; 4. If the substring matches, returns the current position in rax
; 5. if the end of the string is reached without a match, returns 0
strstr:
    ; rdi = main string, rsi = search string
    .loop:
        mov al, [rdi]
        test al, al
        jz .not_found

        push rdi
        push rsi
        .inner_loop:
            mov cl, [rsi]
            test cl, cl
            jz .found
            mov dl, [rdi]
            cmp cl, dl
            jne .not_match
            inc rsi
            inc rdi
            jmp .inner_loop
        
        .not_match:
        pop rsi
        pop rdi
        inc rdi
        jmp .loop

    .found:
    pop rsi
    pop rdi
    mov rax, rdi
    ret

    .not_found:
    xor rax, rax
    ret

error_exit:
    ; Clean Winsock
    call WSACleanup

    ; Exit process
    xor rcx, rcx
    call ExitProcess

close_connection:
    mov rcx, [client_socket]
    call closesocket
    jmp request_loop