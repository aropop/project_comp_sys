; ==============================================================================
;     SHOOTING OBSTACLES GAME
; ==============================================================================
.MODEL large	; multiple data segments and multiple code segments
.STACK 2048  	; stack

; --- INCLUDES -----------------------------------------------------------------

include VIDEO.INC
include RAND.INC
include KEYB.INC

; --- MACROS AND CONSTANTS -----------------------------------------------------

; Other constants	
SCREENW		equ 320
SCREENH		equ 200
PLAYERH		equ 20
PLAYERW		equ 10
PLAYERSTARTY	equ 0
PLAYERX		equ 12

MAXOBSTACLES 	equ 25
MAXBEAMS          equ 50

OBSTACLESPAWNX 	equ 319
OBSTACLEW	equ 10
TIMEBETWEENOBST  equ 10

TIMEBETWEENBEAMS  equ 3
BEAMLENGTH        equ 4

PLAYERCOLOR 	equ 10
OBSTACLECOLOR	equ 60
BEAMCOLOR       equ 34
ENDCOLOR	equ 64

AMOUNTPIXELS	equ 64000

; --- DATA SEGMENT -------------------------------------------------------------
.DATA        ; data segment, variables
oldVideoMode	db ?

hardOffset	dw 0 ; test variable
position	dw 0
positionBeam	dw 0
obstacles	dw 50 dup(0) ;affwisselde x,y van een obstacle
beams           dw 100 dup(0)
level    	dw 2
levelmode	dw 0
levelspeed	dw 1;snelheid waarmee de obstacles bewegen
levelObst	dw 15,13,10,7,5,3,0
dead		db 0 ;bepaald of je dood bent
endcounter	db 0
beamInterval    db 0
obstInterval	db 0

tempTime 	dw 0
time		dw 0

spaceship byte 17,11
            byte PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0,0,0,0,0
            byte 0,PLAYERCOLOR,0,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0,0,0 
            byte 0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,0,0,0,0,0
            byte 0,0,PLAYERCOLOR,0,0,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0
            byte 0,0,0,PLAYERCOLOR,0,PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR,0,0,0
            byte 0,0,0,PLAYERCOLOR,0,0,PLAYERCOLOR,PLAYERCOLOR,0,0,0
            byte 0,0,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0,PLAYERCOLOR,0,0
            byte 0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,PLAYERCOLOR,0,PLAYERCOLOR,0,0
            byte 0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR
            byte 0,PLAYERCOLOR,0,0,0,0,0,0,PLAYERCOLOR,0,0
            byte 0,0,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0,PLAYERCOLOR,0,0
            byte 0,0,0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,0,0,0
            byte 0,0,0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,0,0,0
            byte 0,0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,0,0,0,0
            byte 0,PLAYERCOLOR,0,0,0,PLAYERCOLOR,0,0,0,0,0
            byte 0,PLAYERCOLOR,0,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0,0,0
            byte PLAYERCOLOR,PLAYERCOLOR,PLAYERCOLOR,0,0,0,0,0,0,0,0


; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?	; segment that contains the screenBuffer for mode 13h drawing
palette			db 768 dup(0)
screenBuffer	db 64000 dup(?)	; the 64000 bytes for the screen

; --- CODE SEGMENT -------------------------------------------------------------
.CODE        ; code segment
main PROC NEAR
	mov	ax, @data	; get data segment address
	mov	ds, ax		; set DS to data segment

	; Initialize random number generator
	call	randInit
	
	; Install our own keyboard handler
	call	installKeyboardHandler

	; fade to black
	call	fadeToBlack
	
	; clear video buffer
	call	clearScreenBuffer

	; draw the screen buffer
	call 	updateScreen
	
	; set mode 13h
	mov		ax, 13h
	push	ax
	call	setVideoMode
	mov		[oldVideoMode], al
	;initialiseer de positie van het mannetje	
	mov	[position], PLAYERSTARTY ;ax bevat de y coordinaat van de 

@main_loop:	

	push ax ;preserve
	xor ax, ax
	mov ah, [dead]
	cmp ax, 0
	pop ax ;restore
	jne donotupdate
	call	updateWorld	; this would contain the game code (like AI)
donotupdate:
	call	renderWorld	; draws the world

	call	handleInput	; handle user input


	cmp		al, 0
	jz		@main_loop
	
	; Restore original keyboard handler
	call	uninstallKeyboardHandler

	; Restore original video mode
	mov		al, [oldVideoMode]
	xor		ah, ah
	push	ax
	call	setVideoMode
	
	; Exit to DOS
	mov		ax, 4c00h	; exit to DOS function, return code 00h
	int		21h			; call DOS
main ENDP

; Fades the active colors to black
fadeToBlack PROC NEAR
	push	ax

	mov	ax, seg palette
	push	ax
	mov	ax, offset palette
	push	ax
	call	paletteInitFade
@@:
	waitVBlank
	call	paletteNextFade
	test	ax, ax
	jnz	@B

	pop	ax
	ret 0
fadeToBlack ENDP

; Clears the screen buffer to color 0
clearScreenBuffer PROC NEAR
	push	ax
	push	cx
	push	di
	push	es
	
	cld
	mov		ax, seg screenBuffer
	mov		es, ax
	mov		di, offset screenBuffer
	mov		cx, 64000 / 2
	xor		ax, ax
	rep		stosw
	
	pop	es
	pop	di
	pop	cx
	pop	ax
	ret	0
clearScreenBuffer ENDP

; Updates the screen (copies contents from screenBuffer to screen)
updateScreen PROC NEAR
	push	ax
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	push	es
	
	; setup source and dest segments
	mov		ax, seg screenBuffer
	mov		ds, ax
	mov		si, offset screenBuffer
	mov		ax, 0a000h	; video memory
	mov		es, ax
	xor		di, di	; start at pixel 0
	
	cld
	mov		cx, 64000 / 2
	waitVBlank	; wait for a VB (modifies AX and DX)
	rep		movsw	; blit to screen	
	
	pop		es
	pop		ds
	pop		di
	pop		si
	pop		dx
	pop		cx
	pop		ax
	ret		0
updateScreen ENDP

;Takes y coordinate of our plane
renderWorld PROC NEAR
	
	call	clearScreenBuffer

	; draw a random rectangle
	;call	rand
	;and		ax, 0ffh
	;push	ax
	;call	rand
	;and		ax, 07fh
	;push	ax
	xor 	ax, ax
	mov 	al, [endcounter]
	and	al, [dead]
	cmp 	ax, 00000000b
	jne	drawEndLabel	

	;call 	drawTriangle
      call  drawPlayer	
      call 	drawBeam
      call  createObstacle
	call	drawObstacles

	
	mov [endcounter], 0001b
	jmp dontDrawEnd

drawEndLabel:
	call 	drawEnd
	mov [endcounter], 0000b

dontDrawEnd:

	; draw the screen buffer
	call 	updateScreen
	
	ret	0
renderWorld ENDP

updateWorld PROC NEAR

	call updateObstacles
      call updateBeams
	call updateTime
	call updateLevels

	ret 0
updateWorld ENDP

updateObstacles PROC NEAR
	
	push ax
	push dx
	push bx

	mov bx, 0 ;bx obstacle counter

compareLoop:
      xor ax, ax
	mov ax, obstacles[bx] ;x coordinaat
	
	cmp ax, 0
	je endUpdateObstacles
	mov dx, [levelspeed]
	sub ax, dx
	push ax ;vernieuwde waarden pushen
	sub ax, OBSTACLESPAWNX
	add ax, SCREENW
      sub ax, 1 ;dit is de marge die we toevoegen om ervoor te zorgen dat wanneer iets letterlijk nul is niet als een lege lijst wordt gezien
	;kijken of dit nog op het scherm is
	cmp ax, 0
	jle deleteAndSwap
	pop ax ;voor de volledigheid
	mov obstacles[bx], ax
	add bx, 4 ;2 om x positie te springen 2 om y positie
	jmp compareLoop
deleteAndSwap:
      pop ax      
    call deleteObstacle
	jmp compareLoop
	
endUpdateObstacles:

	pop bx
	pop dx
	pop ax
	


	ret 0
updateObstacles ENDP


deleteObstacle PROC NEAR
      push ax
      push dx
      push bx

      xor ax, ax

      ;kijken of dit de laatste is
      mov ax, obstacles[bx + 4]
      add bx, 4
      cmp ax, 0
      jne @F

      pop bx
      mov obstacles[bx], 0
      mov obstacles[bx + 2], 0
      jmp endDeleteObstacle
	;loopen tot het einde
@@:
	add bx, 4
	mov ax, obstacles[bx]
	cmp ax, 0
	jne @B

	;terug op de vorige bestaande zetten
	sub bx, 4
	mov ax, obstacles[bx]
      mov obstacles[bx], 0
	mov dx, obstacles[bx + 2]
      mov obstacles[bx + 2], 0
	pop bx
	mov obstacles[bx], ax
	mov obstacles[bx + 2], dx
	

endDeleteObstacle:
      pop dx
      pop ax
      ret 0
deleteObstacle ENDP


updateBeams PROC NEAR
	
	push ax
	push dx
	push bx
	

	xor ax, ax
	xor dx, dx
	xor bx, bx ;bx beam counter

compareLoop:
      ;stoppen als meer beams dan er plaats is
      cmp bx, MAXBEAMS*4
      jge endUpdateBeams


	mov ax, beams[bx] ;x coordinaat
	
	cmp ax, 0
	je endUpdateBeams

	mov dx, [levelspeed]
	add ax, dx

	;kijken of dit nog op het scherm is
	cmp ax, SCREENW
	jge deleteThisBeam

	mov beams[bx], ax
	add bx, 4 ;2 om x positie te springen 2 om y positie
	jmp compareLoop

deleteThisBeam:
      call deleteBeam
      jmp compareLoop

endUpdateBeams:

	pop bx
	pop dx
	pop ax
	


	ret 0
updateBeams ENDP
;procedure verwacht in bx een counter voor de beam
deleteBeam PROC NEAR
      push ax
      push dx
      push bx


	;oude index pushen
	push bx
      ;de eerste volgende is al leeg moeten we speciaal behandelen
	add bx, 4
      cmp bx, MAXBEAMS*4 ;devolgende is al aan het eind
      jge noOtherBeams
	mov ax, beams[bx]
	cmp ax, 0 ;de volgende is leeg
	je noOtherBeams
      ;de volgende is niet leeg dan zoeken we tot de laatste hebben gevonden
findLastBeam:
      
      cmp   bx, MAXBEAMS*4
      je    deleteBeamL

      add   bx, 4
      mov   ax, beams[bx]
      cmp   ax, 0
      jne   findLastBeam
deleteBeamL:
	;terug op de vorige bestaande zetten
	sub bx, 4
	mov ax, beams[bx]
      mov beams[bx], 0
	mov dx, beams[bx+2]
      mov beams[bx+2], 0

	pop bx
	mov beams[bx], ax
	mov beams[bx+2], dx

	sub bx, 2 ;vanaf hier moet er nog verplaatst worden
	jmp endDeleteBeam

noOtherBeams:     
      pop   bx ; bx terug goed zetten  
      mov   beams[bx], 0 ;x op nul zetten  
      mov   beams[bx+2], 0  
	
endDeleteBeam:
      pop bx
      pop dx
      pop ax
      ret 0
deleteBeam ENDP

; Reads keyboard buffer and acts (returns non-zero if loop should end, 0 otherwise)
handleInput PROC NEAR
	push	es

	mov	ax, seg __keysActive
	mov	es, ax

	xor	ah, ah
	mov	al, es:[__keysActive]
	cmp	al, 0
	jz	@done		; no key pressed

	cmp	[dead], 0001b
	je	testesc

	; handle keys
	mov	al, es:[__keyboardState][SCANCODE_UP]	; test UP key
	cmp	al, 0
	jz @F	; jump next
	call	goUp

@@:
	mov	al, es:[__keyboardState][SCANCODE_DOWN]	; test DOWN key
	cmp	al, 0
	jz @F	; jump next
	call	goDown	

@@:
	mov	al, es:[__keyboardState][SCANCODE_LEFT]	; test LEFT key
	cmp	al, 0
	jz @F	; jump next
	; call some function to handle this key

@@:
	mov	al, es:[__keyboardState][SCANCODE_RIGHT]	; test RIGHT key
	cmp	al, 0
	jz @F	; jump next
	; call some function to handle this key
	call	createBeam
@@:
testesc:	
	; finally, let's put the ESC key status as return value in AX
	mov	al, es:[__keyboardState][SCANCODE_ESC]	; test ESC

@done:
	
	pop	es
	ret 0
handleInput ENDP


drawPlayer PROC NEAR
      push  di
      push  ax

      mov	di, offset screenBuffer	
	;positie X
	add di, PLAYERX ;di contains position	
	;positie Y
	mov 	ax, [position]
	mov 	dx, SCREENW
	mul	dx
	add	di, ax
      
      mov ax, offset spaceship
      push ax
      push di
      call drawArray

      pop ax
      pop di
      ret   0
drawPlayer ENDP

;Takes the offset and position as parameters
drawArray PROC NEAR
	push bp
	mov bp, sp
	
	push ax
	push bx
	push cx
	push si
	push ds
	push di
	push es
	
	cld
	;screenbuffer
	mov ax, seg screenBuffer
	mov es, ax
	mov ax, [bp+4][0]
	mov di, ax
	;array
	mov ax, @data
	mov ds, ax
	mov ax, [bp+4][2]
	mov si, ax
	;array-width and array-height
	lodsw
	mov cx, 0
	mov bh, ah ;width
	mov bl, al ;height
	
arrayLoop:
	mov cl, bh
	rep movsb ;copy row
	mov ax, SCREENW
	mov cl, bh
	sub ax, cx
	add di, ax ;next row
	dec bl
	jnz arrayLoop
	
	pop es
	pop di
	pop ds
	pop si
	pop cx
	pop bx
	pop ax
	
	mov sp, bp
	pop bp
	ret 4

      
drawArray ENDP

drawObstacles PROC NEAR
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	es	


	; set segment
	mov	ax, seg screenBuffer
	mov	es, ax
	mov	di, offset screenBuffer

	mov 	bx, 0 ;bx is obstacle counter
	mov	ax, 0
	mov	ax, obstacles[bx]

	cmp	ax, 0
	jne	nextobstacle
	jmp	enddrawobstacles

nextobstacle:
      mov   di, offset screenBuffer
	;pos x
	add 	di, obstacles[bx]
	;pos y
	mov 	ax, obstacles[bx+2]
	mov 	dx, SCREENW
	mul	dx
	add	di, ax
      
      ;make sure dx is null for checking if deleted

	mov	ax, 0
	mov 	al, OBSTACLECOLOR
	;omlaag
	push 	bx
	xor 	bx, bx
	mov   bx, [level]
	mov	cx, levelObst[bx]
	pop 	bx
@@:	
      call checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNext
	mov es:[di], al
	add	di, SCREENW
	loop @B

	;rechts
	push 	bx
	xor 	bx, bx
      xor   dx, dx
	mov   bx, [level]
	mov	cx, levelObst[bx]
      pop   bx
      mov   dx, SCREENW
      sub   dx, obstacles[bx] 
      cmp   cx, dx
      jle @F
      mov   cx, dx
@@:
      call checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNext
	mov es:[di], al
	inc	di
	loop @B

	;omhoog
	push 	bx
	xor 	bx, bx
	mov   bx, [level]
	mov	cx, levelObst[bx]
	pop 	bx
@@:
      call checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNext
	mov es:[di], al
	sub di, SCREENW
	loop @B
notUp:
      xor   dx,dx
	;links
	push 	bx
	xor 	bx, bx
      xor   dx, dx
	mov   bx, [level]
	mov	cx, levelObst[bx]
      pop   bx
      mov   dx, SCREENW
      sub   dx, obstacles[bx] 
      cmp   dx, cx
      jge @F
      mov   cx, dx
@@:
      xor   dx,dx
      call  checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNext
	mov   es:[di], al
	dec   di
	loop  @B
	
toNext:
	;inc bx en check if last
	add	bx, 4 ; because we deleted 
	mov	di, 0
	mov 	ax, obstacles[bx]
	cmp 	ax, 0
	je	enddrawobstacles
	jmp	nextobstacle


enddrawobstacles:	


	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	
	ret 0
drawObstacles ENDP

drawBeam PROC NEAR
	push	dx
	push 	di
	push 	bx
	push 	cx
	push 	ax
      push  es

	mov	ax, seg screenBuffer
	mov 	es, ax
	mov	di, offset screenBuffer

	mov 	bx, 0 ; beam counter

draw:	
      cmp   bx, MAXBEAMS*4
      jge   done      

	xor	ax, ax
	mov	ax, beams[bx]
	cmp 	ax,0
	je	done


	mov	di, offset screenBuffer
      ;pos x
	add	di, beams[bx]

      ;determine the length of the beam to prevent it being drawn on the opposite
      ;side of the screen
	mov   cx, SCREENW
      sub   cx, beams[bx]
      cmp   cx, BEAMLENGTH
      jle    @F
      mov   cx, BEAMLENGTH
@@:

      ;pos y
	add 	bx, 2
	mov	ax, beams[bx]
	mov 	dx, SCREENW
	mul	dx
	add	di, ax
	mov 	al, BEAMCOLOR
@@:	
	mov 	es:[di], al
	inc 	di
	loop 	@B

	add	bx, 2
	jmp 	draw
	
done:	
      pop   es
	pop 	ax
	pop	cx
	pop 	bx
	pop	di
	pop	dx
	ret 	0
	
drawBeam ENDP

drawEnd PROC NEAR
	push es
	push ax
	push di
	push cx

	mov	ax, seg screenBuffer
	mov 	es, ax
	mov 	di, offset screenBuffer
	xor	ax, ax
	mov	al, ENDCOLOR
	mov	ah, ENDCOLOR
	mov	cx, 64000/2
	rep 	stosw ;repeats cx times and stows stores in es:di the value of ax


	pop cx
	pop es
	pop ax
	pop di
	
	ret 0
drawEnd ENDP

goUp PROC NEAR
	push 	bx ;saven om zelfde staat te garanderen
	mov 	bx, 1
	cmp	bx, [position]
	jae	@f
	
	mov 	bx, 3
	neg 	bx
	add 	[position], bx ;-2 optellen
@@:
	pop 	bx ; herstellen
	ret 0
goUp ENDP

goDown PROC NEAR 
	
	push ax
	push bx
	;screenh - playerh is de ondergrens
	mov bx, PLAYERH
	neg bx
	mov ax, SCREENH
	add ax, bx
	dec ax ; fout marge
	cmp 	[position], ax
	ja	@F
	add	[position], 3
@@:
	pop bx
	pop ax
	ret 0
goDown ENDP

createObstacle PROC NEAR
	push bx
	push ax

	mov bx, 0
	cmp [obstInterval], 0
        jne decInterval

loopToEnd:
	mov ax, obstacles[bx]
	cmp ax, 0
	je rightindex
	
	mov ax, MAXOBSTACLES
	shl ax, 1
	cmp bx, ax
	jge resetInterval ;no more place for new obstacles
	add bx, 2
	jmp loopToEnd


rightindex:
	call rand
      ;make sure not out of bounds
      mov dx, SCREENH
      push bx
      mov bx, [level]
      sub dx, levelObst[bx]
      sub dx, 5 ;margin
      pop bx
      and ax, dx

	mov obstacles[bx], OBSTACLESPAWNX
	add bx, 2
	mov obstacles[bx], ax	
	jmp resetInterval

decInterval:
	dec [obstInterval]
	jmp done
  
resetInterval:
	mov [obstInterval], TIMEBETWEENOBST

done:
	pop ax
	pop bx
	ret 0
createObstacle ENDP


createBeam PROC NEAR

	push ax
	push dx
	push bx
	push di

	xor ax, ax
	xor bx, bx ;set bx to begin beams-array

      ;test if the interval is nul so that we don't create to much beams
      cmp [beamInterval], 0
      jne decInterval

loopToEnd:
	cmp bx, MAXBEAMS*4
	jge done

	mov ax, beams[bx]
	cmp ax, 0
	je calcPos

	xor ax, ax
	add bx, 4
	jmp loopToEnd


calcPos:
;calculate posX
	xor dx, dx
	add dx, PLAYERX
	add dx, PLAYERW
	mov beams[bx], dx

;calculate posY:

	add 	bx, 2
      xor   ax, ax
	mov 	ax, [position]
	add 	ax, PLAYERH/2
	mov 	beams[bx], ax
      
      ;set the interval on 
      mov   [beamInterval], TIMEBETWEENBEAMS
      jmp   done

decInterval:
      dec   [beamInterval]

done:
;position saved => DONE

	pop di
	pop bx
	pop dx
	pop ax
	ret 0

createBeam ENDP



;procedure verwacht in es de screenBuffer in di de huidige index
;in bx verwacht het de huidige index van het obstacle
checkCollide PROC NEAR
      push ax
      push di

      xor ax, ax
      mov al, es:[di]
      cmp al, PLAYERCOLOR
      jne checkNext
      mov [dead], 0001b

checkNext:
      cmp al, BEAMCOLOR
      jne endCheckCollide
      mov   dx, 1 ; set delete on true
      push obstacles[bx] ;push the x as parameter
      call searchBeamForX
      call deleteObstacle
      

endCheckCollide:
      pop di
      pop ax
      ret 0


checkCollide ENDP

searchBeamForX PROC NEAR
      push        bp
      mov        bp, sp      

      push  ax
      push  bx ;bx is de beam counter
      push  dx
      
      mov   ax, [bp + 4][0]  ;parameter uitlezen  
      xor   bx, bx  
      
beamLoop:
      cmp   bx, MAXBEAMS*4
      jge   exitSearch
      
      mov   dx, beams[bx]
      sub   dx, BEAMLENGTH - 4
      cmp   ax, dx
      je    beamFound

 
      add   bx, 4
      jmp   beamLoop 
        

beamFound:
      call  deleteBeam

exitSearch:
      pop   dx
      pop   bx
      pop   ax
      pop   bp
      ret   2
searchBeamForX ENDP

updateTime PROC NEAR
   
   push ax
 
   inc [tempTime]
   mov ax, 1
   cmp [tempTime], ax
   jl done
   inc [time]
   mov [tempTime], 0
 
 done:
    pop ax
   ret 0
 updateTime ENDP
 
 updateLevels PROC NEAR
   
   push ax
   push bx
   
   mov ax, 100
   cmp [time], ax
   jl done
   cmp [levelmode], 0
   jz changespeed
   mov bx, [level]
   cmp levelObst[bx+2],0
   jz resetTime
   add [level], 2
   mov [levelmode], 0
   jmp resetTime
changespeed: 
   inc [levelspeed]
   inc [levelmode]
   jmp resetTime
resetTime:
   mov [time],0
 done:
   pop bx
   pop ax
   ret 0
 updateLevels ENDP

; _------------------------------- END OF CODE ---------------------------------
END main
