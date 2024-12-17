default rel
global main
extern WSAStartup
extern WSACleanup
extern socket
extern bind
extern listen
extern accept
extern recv
extern send
extern closesocket
extern printf
extern ExitProcess

section .data
    wsa_data times 400 db 0
    ws_version dw 0x0202
    sockaddr:
        dw 2          ; sin_family = AF_INET
        dw 0x391B     ; Port 6969 in big endian
        dd 0          ; INADDR_ANY
    response db "HTTP/1.1 200 OK", 13, 10
             db "Content-Length: 11", 13, 10, 13, 10
             db "Hello World"
    response_len equ $ - response
    error_msg db "Error occurred", 10, 0

section .bss
    socket_fd resq 1
    client_socket resq 1
    buffer resb 1024

section .text
main:
    ; Initialize Winsock
    sub rsp, 40
    mov rcx, ws_version
    mov rdx, wsa_data
    call WSAStartup
    test rax, rax
    jnz error_exit    ; Exit if WSAStartup fails

    ; Create socket
    mov rcx, 2        ; AF_INET
    mov rdx, 1        ; SOCK_STREAM
    mov r8, 0         ; Protocol
    call socket
    test rax, rax
    js error_exit     ; Exit if socket creation fails
    mov [socket_fd], rax

    ; Bind socket
    mov rcx, [socket_fd]
    lea rdx, [sockaddr]
    mov r8, 16        ; Size of sockaddr_in
    call bind
    test rax, rax
    js error_exit     ; Exit if bind fails

    ; Listen
    mov rcx, [socket_fd]
    mov rdx, 5        ; Backlog
    call listen
    test rax, rax
    js error_exit     ; Exit if listen fails

server_loop:
    ; Accept connection
    mov rcx, [socket_fd]
    xor rdx, rdx
    xor r8, r8
    call accept
    test rax, rax
    js error_exit     ; Exit if accept fails
    mov [client_socket], rax

    ; Receive request (optional, just to clear buffer)
    mov rcx, [client_socket]
    lea rdx, [buffer]
    mov r8, 1024
    xor r9, r9
    call recv

    ; Send response
    mov rcx, [client_socket]
    lea rdx, [response]
    mov r8, response_len
    xor r9, r9
    call send

    ; Close client socket
    mov rcx, [client_socket]
    call closesocket

    jmp server_loop

error_exit:
    ; Print error message
    lea rcx, [error_msg]
    call printf

    ; Cleanup Winsock
    call WSACleanup

    ; Exit process
    xor rcx, rcx
    call ExitProcess