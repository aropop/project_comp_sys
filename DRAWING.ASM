; ==============================================================================
; Example for buffered drawing in mode 13h.
; Example showing palette manipulation via port IO.
; Example for a very generic game-loop.
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

MAXOBSTACLES 	equ 5
MAXBEAMS          equ 50
OBSTACLEW	equ 5

OBSTACLESPAWNX 	equ 319

TIMEBETWEENBEAMS  equ 3

PLAYERCOLOR 	equ 10
OBSTACLECOLOR	equ 60
BEAMCOLOR         equ 34
ENDCOLOR	equ 64

AMOUNTPIXELS	equ 64000

; --- DATA SEGMENT -------------------------------------------------------------
.DATA        ; data segment, variables
oldVideoMode	db ?

hardOffset	dw 0 ; test variable
position	dw 0
positionBeam	dw 0
obstacles	dw OBSTACLESPAWNX,40,0,0,0,0,0,0,0,0 ;affwisselde x,y van een obstacle
beams       dw 100 dup(0)
levelspeed	dw 1 ;snelheid waarmee de obstacles bewegen
dead		db 0 ;bepaald of je dood bent
endcounter	db 0
beamInterval db 0


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

	call 	drawTriangle
	call 	drawBeam

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

	ret 0
updateWorld ENDP

updateObstacles PROC NEAR
	
	push ax
	push dx
	push bx

	mov bx, 0 ;bx obstacle counter

compareLoop:
	mov ax, obstacles[bx] ;x coordinaat
	
	cmp ax, 0
	je endUpdateObstacles
	mov dx, [levelspeed]
	sub ax, dx
	push ax ;vernieuwde waarden pushen
	sub ax, OBSTACLESPAWNX
	add ax, SCREENW
	;kijken of dit nog op het scherm is
	cmp ax, 0
	pop ax ;voor de volledigheid
	jle deleteAndSwap
	mov obstacles[bx], ax
	add bx, 4 ;2 om x positie te springen 2 om y positie
	jmp compareLoop

deleteAndSwap:
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
	;oude index pushen
	push bx
      ;kijken of dit de laatste is
      mov ax, obstacles[bx + 4]
      cmp ax, 0
      jne @F
      mov obstacles[bx], 0
      mov obstacles[bx + 2], 0
      pop bx
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
	add bx, 2 ;y coordinaat
	mov dx, obstacles[bx]
	pop bx
	mov obstacles[bx], ax
	add bx, 2
	mov obstacles[bx], dx
	sub bx, 2 ;vanaf hier moet er nog verplaatst worden

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
	jge deleteAndSwap

	mov beams[bx], ax
	add bx, 4 ;2 om x positie te springen 2 om y positie
	jmp compareLoop

deleteAndSwap:
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
      je    deleteBeam

      add   bx, 4
      mov   ax, beams[bx]
      cmp   ax, 0
      jne   findLastBeam
deleteBeam:
	;terug op de vorige bestaande zetten
	sub bx, 4
	mov ax, beams[bx]
      mov beams[bx], 0
	add bx, 2 ;y coordinaat
	mov dx, beams[bx]
      mov beams[bx], 0

	pop bx
	mov beams[bx], ax
	add bx, 2
	mov beams[bx], dx

	sub bx, 2 ;vanaf hier moet er nog verplaatst worden
	jmp compareLoop

noOtherBeams:     
      pop   bx ; bx terug goed zetten  
      mov   beams[bx], 0 ;x op nul zetten    
	;de functie is gedaan

endUpdateBeams:

	pop bx
	pop dx
	pop ax
	


	ret 0
updateBeams ENDP

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

; Draw a rectangle at the center of the screen buffer.
; W, H passed on stack.
drawRect PROC NEAR
	push	bp
	mov	bp, sp
	
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	es
	
	; set segment
	mov	ax, seg screenBuffer
	mov	es, ax
	
	
	; Calculate posX
	mov	ax, [bp + 4][2]
	neg	ax
	add	ax, SCREENW
	shr	ax, 1
	mov	bx, ax		; posX is in BX now
	
	; Calculate posY
	mov	ax, [bp + 4][0]
	neg	ax
	add	ax, SCREENH
	shr	ax, 1		; and posY is in AX
	
	; Calculate offset of top-left corner
	mov	dx, SCREENW
	mul	dx		; AX = posY * SCREENW
	add	ax, bx		; AX now contains start offset of rectangle
	add	ax, offset screenBuffer ;offset in het segment
	add	ax, [hardOffset]
	
	; Draw upper horizontal line
	mov	di, ax
	mov	cx, [bp + 4][2]	; rect W
	mov	al, 15	; color
	cld
	rep	stosb	; draw	
	
	; Draw right vertical line	
	mov	cx, [bp + 4][0]	; rect H
	dec	di
@@:
	mov	es:[di], al	; set pixel
	add	di, SCREENW	; jump to next pixel (on next line)
	loop	@B ;loopt tot di null is
	
	; Draw bottom horizontal line
	mov	cx, [bp+4][2]	; rect W
	std	; count backwards
	rep	stosb	; draw
	
	; Draw left vertical line
	mov	cx, [bp + 4][0]	; rect H
	inc di
@@:
	mov	es:[di], al	; set pixel
	sub	di, SCREENW	; jump to next pixel (on next line)
	loop	@B

	; We are done
	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	; return
	pop	bp
	ret	4
drawRect ENDP


;Draws a triangle
;W,H and position y is passed on stack

drawTriangle PROC NEAR
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

	
	;positie X
	add di, PLAYERX ;di contains position
	
	
	;positie Y
	mov 	ax, [position]
	mov 	dx, SCREENW
	mul	dx
	add	di, ax

	;set al to color
	mov 	al, PLAYERCOLOR

	; Draw slope to right
	mov	cx, PLAYERW	; triangle W
	dec	di
@@:
	mov	es:[di], al	; set pixel, se is een screenbuffer array, op plek di zet je de kleur al
	add	di, SCREENW	; jump to next pixel (on next line)
	add 	di, 1
	loop	@B ;loopt tot cx null is


	; Draw slope to left
	mov	cx, PLAYERW ; triangle W terug in cx stoppen	
	dec	 di
@@:
	mov es:[di], al
	add	di, SCREENW
	dec 	di
	loop	@B

	;Draw Vertical line
	mov 	cx, PLAYERH  ; triangle H
	sub 	di, SCREENW
@@:
	mov 	es:[di], al
	sub 	di, SCREENW
	loop	@B


	; We are done
	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret	0

	

drawTriangle ENDP

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
	je	enddrawobstacles

nextobstacle:
	;pos x
	add 	di, obstacles[bx]
	;pos y
	add 	bx,2 ;Add 2 because we use words
	mov 	ax, obstacles[bx]
	mov 	dx, SCREENW
	mul	dx
	add	di, ax

      ;sub voor de checkcollide
      sub   bx, 2

	mov	ax, 0
	mov 	al, OBSTACLECOLOR
	;omlaag
	mov	cx, OBSTACLEW
@@:	
      call checkCollide
	mov es:[di], al
	sub	di, SCREENW
	loop @B

	;rechts
	mov cx, OBSTACLEW
	
@@:
      call checkCollide
	mov es:[di], al
	inc	di
	loop @B

	;omhoog
	mov cx, OBSTACLEW
@@:
      call checkCollide
	mov es:[di], al
	add di, SCREENW
	loop @B

	;links
	mov cx, OBSTACLEW
@@:
      call checkCollide
	mov es:[di], al
	dec di
	loop @B
	

	;inc bx en check if last
	add	bx, 4 ; because we deleted 
	mov	di, 0
	mov 	ax, obstacles[bx]
	cmp 	ax, 0
	jne	nextobstacle


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
	add	di, beams[bx]
	add 	bx, 2
	mov	ax, beams[bx]
	mov 	dx, SCREENW
	mul	dx
	add	di, ax
	mov 	al, BEAMCOLOR
	mov 	cx, 4 
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
	
	mov 	bx, 2
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
	add	[position], 2
@@:
	pop bx
	pop ax
	ret 0
goDown ENDP

createObstacle PROC NEAR
	push bx
	push ax

	mov bx, 0
loopToEnd:
	mov ax, obstacles[bx]
	cmp ax, 0
	je rightindex
	
	mov ax, MAXOBSTACLES
	shl ax, 1
	cmp bx, ax
	jge done ;no more place for new obstacles
	add bx, 2
	jmp loopToEnd


rightindex:
	call rand
	and ax, 00CFh
	mov obstacles[bx], OBSTACLESPAWNX
	add bx, 2
	mov obstacles[bx], ax	

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

      xor ax, ax
      mov ax, es:[di]
      cmp ax, PLAYERCOLOR
      jne checkNext
      mov [dead], 0001b
checkNext:
      cmp ax, BEAMCOLOR
      jne endCheckCollide
      call deleteObstacle

      

endCheckCollide:
      pop ax
      ret 0


checkCollide ENDP

; _------------------------------- END OF CODE ---------------------------------
END main
