%include "/usr/local/share/csc314/asm_io.inc"

; speed of movment thingy
%define TICK 50000

; the file that stores the initial state
%define BOARD_FILE 'board.txt'

; how to represent everything
%define WALL_CHAR '#'

; the size of the game screen in characters
%define HEIGHT 40
%define WIDTH 80

; the player starting position.
; top left is considered (0,0)
%define STARTX 2
%define STARTY 20

%define STARTX2 77
%define STARTY2 20

%define STARTDIRX 1
%define STARTDIRY 0

%define STARTDIRX2 -1
%define STARTDIRY2 0

; these keys do things
%define EXITCHAR 'x'

%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'

%define UPCHAR2 'i'
%define LEFTCHAR2 'j'
%define DOWNCHAR2 'k'
%define RIGHTCHAR2 'l'

%define PLAYERUP '^'
%define PLAYERDOWN 'v'
%define PLAYERLEFT '<'
%define PLAYERRIGHT '>'


segment .data

        ; used to fopen() the board file defined above
        board_file                      db BOARD_FILE,0

        ; used to change the terminal mode
        mode_r                          db "r",0
        raw_mode_on_cmd         db "stty raw -echo",0
        raw_mode_off_cmd        db "stty -raw echo",0

        ; called by system() to clear/refresh the screen
        clear_screen_cmd        db "clear",0

        ; things the program will print
        help_str                        db 13,10,"Controls: ", \
                                                        UPCHAR,"=UP / ", \
                                                        LEFTCHAR,"=LEFT / ", \
                                                        DOWNCHAR,"=DOWN / ", \
                                                        RIGHTCHAR,"=RIGHT / ", \
                                                        EXITCHAR,"=EXIT", \
                                                        13,10,10,0

        tie_str                         db "The game ended in a tie.",0
        one_win                         db "Player 1 wins the game.",0
        two_win                         db "Player 2 wins the game.",0

        game_end_flag           db      0

segment .bss

        ; this array stores the current rendered gameboard (HxW)
        board   resb    (HEIGHT * WIDTH)

        ; these variables store the current player position
        xpos    resd    1
        ypos    resd    1

        xpos2   resd    1
        ypos2   resd    1

        xdir    resd    1
        ydir    resd    1

        xdir2   resd    1
        ydir2   resd    1

        PLAYERCHAR resb 1
        PLAYERCHAR2 resb 1

        CURRENTMOVECHAR resb 1

segment .text

        global  asm_main
        global  raw_mode_on
        global  raw_mode_off
        global  init_board
        global  render

        extern  system
        extern  putchar
        extern  getchar
        extern  printf
        extern  fopen
        extern  fread
        extern  fgetc
        extern  fclose

        extern usleep
        extern fcntl

asm_main:
        enter   0,0
        pusha
        ;***************CODE STARTS HERE***************************

        ; put the terminal in raw mode so the game works nicely
        call    raw_mode_on

        ; read the game board file into the global variable
        call    init_board

        mov     BYTE[PLAYERCHAR],       PLAYERRIGHT
        mov             BYTE[PLAYERCHAR2],      PLAYERLEFT

        ; set the player at the proper start position
        mov             DWORD [xpos], STARTX
        mov             DWORD [ypos], STARTY
        ; set position of player 2
        mov             DWORD [xpos2], STARTX2
        mov             DWORD [ypos2], STARTY2

        ; sets the starting directon of player 1
        mov             DWORD [xdir], STARTDIRX
        mov             DWORD [ydir], STARTDIRY
        ; sets the starting direction of player 2
        mov             DWORD [xdir2], STARTDIRX2
        mov             DWORD [ydir2], STARTDIRY2

        ; the game happens in this loop
        ; the steps are...
        ;   1. render (draw) the current board
        ;   2. get a character from the user
        ;       3. store current xpos,ypos in esi,edi
        ;       4. update xpos,ypos based on character from user
        ;       5. check what's in the buffer (board) at new xpos,ypos
        ;       6. if it's a wall, reset xpos,ypos to saved esi,edi
        ;       7. otherwise, just continue! (xpos,ypos are ok)
        game_loop:

                ; usleep(TICK)
                push    TICK
                call    usleep
                add             esp, 4

                ; draw the game board
                call    render

                ; get an action from the user
                call    nonblocking_getchar

                ;this is whre the inital  movement char is set cl for player 1 ch for player two this probably should be a variable but that would require me to move stuff around later and im lazy
                mov             cl, '|'
                mov             ch, '|'

                cmp             DWORD[xdir], 0
                je switchchartwo

                mov             cl, '-'

                switchchartwo:

                cmp             DWORD[xdir2], 0
                je switchcharend

                mov             ch, '-'

                switchcharend:

                ; choose what to do
                cmp             eax, EXITCHAR
                je              game_loop_end_on_key
                cmp             eax, UPCHAR
                je              move_up
                cmp             eax, LEFTCHAR
                je              move_left
                cmp             eax, DOWNCHAR
                je              move_down
                cmp             eax, RIGHTCHAR
                je              move_right


                cmp             eax, UPCHAR2
                je              move_up2
                cmp             eax, LEFTCHAR2
                je              move_left2
                cmp             eax, DOWNCHAR2
                je              move_down2
                cmp             eax, RIGHTCHAR2
                je              move_right2

                jmp             input_end                       ; or just do nothing

                ; move the player according to the input character
                move_up:
                        ; this checks if the player is attempting to turn 180 degrees like ---> to <---
                        cmp     DWORD[ydir], 0
                        jne             input_end
                        ; using 0s 1s and -1s allows me to just add so I switch this here and add later to the thingy
                        mov             DWORD[xdir], 0
                        mov             DWORD[ydir], -1
                        mov     BYTE[PLAYERCHAR],       PLAYERUP
                        ; when the person changes direction an o is printed its stored here
                        mov             cl, 'o'
                        jmp             input_end
                move_left:
                        cmp     DWORD[xdir], 0
                        jne             input_end

                        mov             DWORD[xdir], -1
                        mov             DWORD[ydir], 0
                        mov     BYTE[PLAYERCHAR],       PLAYERLEFT
                        mov             cl, 'o'
                        jmp             input_end
                move_down:
                        cmp     DWORD[ydir], 0
                        jne             input_end

                        mov             DWORD[xdir], 0
                        mov             DWORD[ydir], 1
                        mov     BYTE[PLAYERCHAR],       PLAYERDOWN
                        mov             cl, 'o'
                        jmp             input_end
                move_right:
                        cmp     DWORD[xdir], 0
                        jne             input_end

                        mov             DWORD[xdir], 1
                        mov             DWORD[ydir], 0
                        mov     BYTE[PLAYERCHAR],       PLAYERRIGHT
                        mov             cl, 'o'
                        jmp             input_end
                move_up2:
                        cmp     DWORD[ydir2], 0
                        jne             input_end

                        mov             DWORD[xdir2], 0
                        mov             DWORD[ydir2], -1
                        mov     BYTE[PLAYERCHAR2],      PLAYERUP
                        mov             ch, 'o'
                        jmp             input_end
                move_left2:
                        cmp     DWORD[xdir2], 0
                        jne             input_end

                        mov             DWORD[xdir2], -1
                        mov             DWORD[ydir2], 0
                        mov     BYTE[PLAYERCHAR2],      PLAYERLEFT
                        mov             ch, 'o'
                        jmp             input_end
                move_down2:
                        cmp     DWORD[ydir2], 0
                        jne             input_end

                        mov             DWORD[xdir2], 0
                        mov             DWORD[ydir2], 1
                        mov     BYTE[PLAYERCHAR2],      PLAYERDOWN
                        mov             ch, 'o'
                        jmp             input_end
                move_right2:
                        cmp     DWORD[xdir2], 0
                        jne             input_end

                        mov             DWORD[xdir2], 1
                        mov             DWORD[ydir2], 0
                        mov     BYTE[PLAYERCHAR2],      PLAYERRIGHT
                        mov             ch, 'o'
                        jmp             input_end
                input_end:

                ; this decides what movment char player will use

                ; this is the error flag
                mov edx, 0

                ; (W * y) + x = pos

                mov             esi, [xpos]
                mov             edi, [ypos]


                mov eax, WIDTH
                mul DWORD [ypos]
                add eax,[xpos]
                mov BYTE[board + eax], cl

                mov             ebx, DWORD[xdir]
                add     DWORD[xpos], ebx

                mov             ebx, DWORD[ydir]
                add     DWORD[ypos], ebx

                ; compare the current position to the wall character
                mov             eax, WIDTH
                mul             DWORD [ypos]
                add             eax, [xpos]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHAR
                je              breakthingy
                cmp             BYTE [eax], '|'
                je              breakthingy
                cmp             BYTE [eax], '-'
                je              breakthingy
                cmp             BYTE [eax], 'o'
                je              breakthingy

                        jmp check_one_one
                        breakthingy:
                        ; bad move end game
                        mov DWORD[game_end_flag], 1
                        jmp valid_move2
                check_one_one:
                ; this checks if player moves onto other player
                cmp             esi, [xpos2]
                jne             valid_move2
                cmp             edi, [ypos2]
                jne     valid_move2
                        ; bad move end game
                        mov dl, 2
                        jmp game_loop_end
;               jmp valid_move

                ; this checks if second player move is valid
                valid_move2:

                mov             esi, [xpos2]
                mov             edi, [ypos2]

                mov eax, WIDTH
                mul DWORD [ypos2]
                add eax, [xpos2]
                mov BYTE[board + eax], ch

                mov             ebx, DWORD[xdir2]
                add     DWORD[xpos2], ebx

                mov             ebx, DWORD[ydir2]
                add     DWORD[ypos2], ebx
                ; ----
                mov             eax, WIDTH
                mul             DWORD [ypos2]
                add             eax, [xpos2]
                lea             eax, [board + eax]
                cmp             BYTE [eax], WALL_CHAR
                je              breakthingy
                cmp             BYTE [eax], '|'
                je              breakthingy
                cmp             BYTE [eax], '-'
                je              breakthingy
                cmp             BYTE [eax], 'o'
                je              breakthingy

                        jmp check_two_one
                        breakthingy2:
                        ; bad move end game
                        mov dh, 1
                        jmp game_loop_end
                check_two_one:
                cmp             esi, [xpos]
                jne             valid_move
                cmp             edi, [ypos]
                jne     valid_move
                        ; bad move end game
                        mov dl, 2
                        jmp game_loop_end

                valid_move:

                ; check if dl is 1 in case dh is not 1
                cmp DWORD[game_end_flag], 1
                je game_loop_end

        jmp             game_loop
        game_loop_end:

        call game_end

        game_loop_end_on_key:


        ; restore old terminal functionality
        call raw_mode_off

        ;***************CODE ENDS HERE*****************************
        popa
        mov             eax, 0
        leave
        ret

; === FUNCTION ===
game_end:
        push ebp
        mov ebp, esp

        mov ecx, DWORD[game_end_flag]
        cmp dl, 2
        jne next_check_end

                mov eax, tie_str
                jmp game_end_end

        next_check_end:

                cmp ecx, 1
                jne next_check_end2

                        cmp dh, 1
                        jne non_tie_check_end

                                mov eax, tie_str
                                jmp game_end_end

                        non_tie_check_end:

                        mov eax, two_win
                        jmp game_end_end
        next_check_end2:

                mov eax, one_win

        game_end_end:

        call print_string

        mov esp, ebp
        pop ebp
        ret


; === FUNCTION ===
raw_mode_on:

        push    ebp
        mov             ebp, esp

        push    raw_mode_on_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
raw_mode_off:

        push    ebp
        mov             ebp, esp

        push    raw_mode_off_cmd
        call    system
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
init_board:

        push    ebp
        mov             ebp, esp

        ; FILE* and loop counter
        ; ebp-4, ebp-8
        sub             esp, 8

        ; open the file
        push    mode_r
        push    board_file
        call    fopen
        add             esp, 8
        mov             DWORD [ebp-4], eax

        ; read the file data into the global buffer
        ; line-by-line so we can ignore the newline characters
        mov             DWORD [ebp-8], 0
        read_loop:
        cmp             DWORD [ebp-8], HEIGHT
        je              read_loop_end

                ; find the offset (WIDTH * counter)
                mov             eax, WIDTH
                mul             DWORD [ebp-8]
                lea             ebx, [board + eax]

                ; read the bytes into the buffer
                push    DWORD [ebp-4]
                push    WIDTH
                push    1
                push    ebx
                call    fread
                add             esp, 16

                ; slurp up the newline
                push    DWORD [ebp-4]
                call    fgetc
                add             esp, 4

        inc             DWORD [ebp-8]
        jmp             read_loop
        read_loop_end:

        ; close the open file handle
        push    DWORD [ebp-4]
        call    fclose
        add             esp, 4

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
render:

        push    ebp
        mov             ebp, esp

        ; two ints, for two loop counters
        ; ebp-4, ebp-8
        sub             esp, 8

        ; clear the screen
        push    clear_screen_cmd
        call    system
        add             esp, 4

        ; print the help information
        push    help_str
        call    printf
        add             esp, 4

        ; outside loop by height
        ; i.e. for(c=0; c<height; c++)
        mov             DWORD [ebp-4], 0
        y_loop_start:
        cmp             DWORD [ebp-4], HEIGHT
        je              y_loop_end

                ; inside loop by width
                ; i.e. for(c=0; c<width; c++)
                mov             DWORD [ebp-8], 0
                x_loop_start:
                cmp             DWORD [ebp-8], WIDTH
                je              x_loop_end

                        ; check if (xpos,ypos)=(x,y)
                        mov             eax, [xpos]
                        cmp             eax, DWORD [ebp-8]
                        jne             player_two_check
                        mov             eax, [ypos]
                        cmp             eax, DWORD [ebp-4]
                        jne             player_two_check
                                ; if both were equal, print the player
                                push    DWORD[PLAYERCHAR]
                                jmp             print_end

                        player_two_check:
                        ; check if xpos2,ypox2 = x2,y2
                        mov             eax, [xpos2]
                        cmp             eax, DWORD [ebp-8]
                        jne             print_board
                        mov             eax, [ypos2]
                        cmp             eax, DWORD [ebp-4]
                        jne             print_board
                                ; if both were equal, print the player
                                push    DWORD[PLAYERCHAR2]
                                jmp             print_end



                        print_board:
                                ; otherwise print whatever's in the buffer
                                mov             eax, [ebp-4]
                                mov             ebx, WIDTH
                                mul             ebx
                                add             eax, [ebp-8]
                                mov             ebx, 0
                                mov             bl, BYTE [board + eax]
                                push    ebx
                        print_end:
                        call    putchar
                        add             esp, 4

                inc             DWORD [ebp-8]
                jmp             x_loop_start
                x_loop_end:

                ; write a carriage return (necessary when in raw mode)
                push    0x0d
                call    putchar
                add             esp, 4

                ; write a newline
                push    0x0a
                call    putchar
                add             esp, 4

        inc             DWORD [ebp-4]
        jmp             y_loop_start
        y_loop_end:

        mov             esp, ebp
        pop             ebp
        ret

; === FUNCTION ===
nonblocking_getchar:

; returns -1 on no-data
; returns char on succes

; magic values
%define F_GETFL 3
%define F_SETFL 4
%define O_NONBLOCK 2048
%define STDIN 0

        push    ebp
        mov             ebp, esp

        ; single int used to hold flags
        ; single character (aligned to 4 bytes) return
        sub             esp, 8

        ; get current stdin flags
        ; flags = fcntl(stdin, F_GETFL, 0)
        push    0
        push    F_GETFL
        push    STDIN
        call    fcntl
        add             esp, 12
        mov             DWORD [ebp-4], eax

        ; set non-blocking mode on stdin
        ; fcntl(stdin, F_SETFL, flags | O_NONBLOCK)
        or              DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        call    getchar
        mov             DWORD [ebp-8], eax

        ; restore blocking mode
        ; fcntl(stdin, F_SETFL, flags ^ O_NONBLOCK
        xor             DWORD [ebp-4], O_NONBLOCK
        push    DWORD [ebp-4]
        push    F_SETFL
        push    STDIN
        call    fcntl
        add             esp, 12

        mov             eax, DWORD [ebp-8]

        mov             esp, ebp
        pop             ebp
        ret
