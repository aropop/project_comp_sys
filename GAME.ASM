; ==============================================================================
;     SHOOTING OBSTACLES GAME
; ==============================================================================
.MODEL large	; multiple data segments and multiple code segments
.STACK 2048  	; stack

; --- INCLUDES -----------------------------------------------------------------

include VIDEO.INC
include RAND.INC
include KEYB.INC
include SPRITES.INC
include DRAWP.INC
include GAME.INC

; --- DATA SEGMENT -------------------------------------------------------------
.DATA        ; data segment, variables
oldVideoMode	db ?

position	      dw 0 ;Y position of the player
obstacles	      dw 50 dup(0) ;X,Y of the obstacles
beams             dw 100 dup(0) ; X,Y of the beams
level    	      dw 2 ;current level
levelmode	      dw 0 ;
levelspeed	      dw 1 ;speed of the obstacles
levelObst	      dw 15,13,10,7,5,3,0 ;size of the obstacles
dead		      db 0 ;bepaald of je dood bent
endcounter	      db 0 ;counter to make it flash
beamInterval      db 0 ;interval between 2 beams
obstInterval	db 0 ;interval between 2 obstacles
drawCheck         db 0 ;checkt of er halve dingen getekend moeten worden of niet
score 		dw 29;Score of the player
tempTime 	      dw 0 ;time counters
time		      dw 0 ;time counters (2 because of the speed of each loop)
started           db 0 ;determines wheter we started the game already

PUBLIC position, obstacles, beams, dead, endcounter, drawCheck, score, started, screenBuffer, level, levelObst, checkCollide, updateScreen

; --- SCREEN BUFFER ------------------------------------------------------------
.FARDATA?	; segment that contains the screenBuffer for mode 13h drawing
palette			db 768 dup(0)
screenBuffer	      db 64000 dup(?)	; the 64000 bytes for the screen

; --- CODE SEGMENT -------------------------------------------------------------
.CODE        ; code segment
main PROC NEAR
	mov	ax, @data	; get data segment address
	mov	ds, ax		; set DS to data segment

	; Initialize random number generator
	call	randInit
	
	; Install our own keyboard handler
	call	installKeyboardHandler
      

	; memorize the old video mode
	mov	ax, 13h
	push	ax
	call	setVideoMode
	mov	[oldVideoMode], al

@reset:
	; fade to black
	call	fadeToBlack
	
	; clear video buffer
	call	clearScreenBuffer

	; draw the screen buffer
	call 	updateScreen

      ;clear data registers for when we are resetting
      call  clearData
	
	; set mode 13h
	mov	ax, 13h
	push	ax
	call	setVideoMode

	;initialize the position of the player
	mov	[position], PLAYERSTARTY 

;start main loop
@main_loop:	

      ;Check if we are started yet
      cmp [started], 0
      je  notStarted

      ;Check if player is dead
	push ax ;preserve
	xor ax, ax
	mov ah, [dead]
	cmp ax, 0
	pop ax ;restore
	jne donotupdate ;do not update the world (because we are dead)
	call	updateWorld	

donotupdate: ;render the world
	call	renderWorld	; draws the world
      cmp   [endcounter], 111111b
      je    @reset
      jmp   handleOnlyInput ;Jump over the beginning commands

notStarted: ;draw the begin screen
      call  drawBegin

handleOnlyInput: ;handle the input
	call	handleInput	; handle user input

	cmp	al, 0 ;as long esc is not pressed we continue
	jz	@main_loop
	
	; Restore original keyboard handler
	call	uninstallKeyboardHandler

	; Restore original video mode
	mov	al, [oldVideoMode]
	xor	ah, ah
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

;Clears all the data for a reset
clearData PROC NEAR
      push  bx
      push  cx

      xor   bx, bx
      mov   cx, MAXOBSTACLES 
@@:
      mov   [obstacles][bx], 0
      mov   [obstacles][bx + 2], 0
      add   bx, 4
      loop  @B

      xor   bx, bx
      mov   cx, MAXBEAMS 
@@:
      mov   [beams][bx], 0
      mov   [beams][bx + 2], 0
      add   bx, 4
      loop  @B

      mov   [position], PLAYERX
      mov   [level], 2
      mov   [levelmode], 0
      mov   [levelspeed], 1
      mov   [dead], 0
      mov   [endcounter], 0
      mov   [beamInterval], 0
      mov   [obstInterval], 0
      mov   [drawCheck], 0
      mov   [score], 29
      mov   [tempTime], 0
      mov   [time], 0
      mov   [started], 0

      pop   cx
      pop   bx
      ret 0
clearData ENDP

; Clears the screen buffer to color 0 (black)
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
updateScreen PROC FAR
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

;handles all the draw functions except the begin draw
renderWorld PROC NEAR
	
	call	clearScreenBuffer

      ;Check if player is dead
	xor 	ax, ax
	mov 	al, [endcounter]
	and	al, [dead] ;can only be 0001 or 0000
	cmp 	al, 0001b ;Flash red once, then draw the situation how the player died, then repeat
	je	drawEndLabel ;end drawing (red screen)

      call  drawPlayer	
      call 	drawBeam
      call  createObstacle
	call	drawObstacles
      call 	drawScore
      
      cmp   [dead], 0
      je   dontDrawEnd
      inc   [endcounter]
	
	jmp dontDrawEnd

drawEndLabel: ;draw red screen
	call 	drawEnd
	inc [endcounter]

dontDrawEnd:

	; draw the screen buffer
	call 	updateScreen
	
	ret	0
renderWorld ENDP

;Updates the elements in the world
updateWorld PROC NEAR

	call updateObstacles
      call updateBeams
	call updateTime
	call updateLevels

	ret 0
updateWorld ENDP

;Updates the obstacles (places them closer to the player and deletes when they aren't relevant any more)
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

;Deletes an obstacle
;Takes the obstacle counter in bx
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

;Updates the placement of the beams
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

;Deletes the beam from the screen
;Takes in bx the beam counter
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
	mov	al, es:[__keyboardState][SCANCODE_RIGHT]	; test RIGHT key
	cmp	al, 0
	jz @F	; jump next
	; call some function to handle this key
	call	createBeam
@@:

      mov   al, es:[__keyboardState][SCANCODE_ENTER]
      cmp   al, 0
      jz    @F
      mov   [started], 1
@@:
testesc:	
	; finally, let's put the ESC key status as return value in AX
	mov	al, es:[__keyboardState][SCANCODE_ESC]	; test ESC

@done:
	
	pop	es
	ret 0
handleInput ENDP

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
      push cx
      push dx
	push bx
	push ax

	mov bx, 0
	cmp [obstInterval], 0
      jg decInterval

loopToEnd:
	mov ax, obstacles[bx]
	cmp ax, 0
	je rightindex
	
      xor   ax,ax
	mov   ax, MAXOBSTACLES
	shl   ax, 1
	cmp   bx, ax
	jge   resetInterval ;no more place for new obstacles
	add   bx, 2
	jmp   loopToEnd


rightindex:
	call rand
      ;make sure not out of bounds
      and ax, 11111111b
      sub ax, 54
      cmp ax, 0 ; too small
      jg @F
      jmp rightindex
@@:
      ;too big
      push bx
      push ax
      mov bx, [level]
      mov dx, levelObst[bx]      
      mov ax, SCREENH
      sub ax, dx
      mov dx, ax
      pop ax
      pop bx
      cmp ax, dx
      jg rightindex


	mov obstacles[bx], OBSTACLESPAWNX
	mov obstacles[bx + 2], ax	
	jmp resetInterval

decInterval:
      mov   cx, [level]
      shr   cx, 1
@@:
	sub [obstInterval], 1
      js  done   
      loop @B
	jmp done
  
resetInterval:
	mov [obstInterval], TIMEBETWEENOBST

done:
	pop ax
	pop bx
      pop dx
      pop cx
	ret 0
createObstacle ENDP


createBeam PROC NEAR

	push ax
	push dx
	push bx
	push di

	xor ax, ax
	xor bx, bx ;set bx to begin beams-array

      ;test if score is not null
      cmp [score], 0
      jle done

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
      mov   ax, BULLETPENALTY
      call  updateScore
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
checkCollide PROC FAR
      push ax
      push di

      xor ax, ax
      mov al, es:[di]
      cmp al, PLAYERCOLOR
      jne checkNext
      mov [dead], 1

checkNext:
      cmp al, BEAMCOLOR
      jne endCheckCollide
      mov   dx, 1 ; set delete on true
      
      ;udpate score
      push ax
      mov  ax, ENEMYSCORE
      call updateScore
      pop ax

      ;delete beam
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
      sub   dx, BEAMLENGTH
      cmp   ax, dx
      je    beamFound
      mov   cx, 5
@@:
      inc   dx
      cmp   ax, dx
      je    beamFound
      loop  @B

      mov   cx, 5
      add   dx, 5
@@:
      dec   dx
      cmp   ax, dx
      je    beamFound
      loop  @B

 
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
   
   mov ax, TIMEBETWEENLEVELS
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


;increases or decrease the score
;takes the amount to increase or decrease in ax
updateScore PROC NEAR
      push dx

      cmp ax, 0
      jns @F ;when adding there is no problem
      mov dx, [score] ;check if the score is not below zero
      cmp dx, 0
      jle noScoreUpdate
@@:     
      add [score], ax
      mov ax, [score]
      cmp [score], 0
      jge noScoreUpdate
      
      mov [score], 0
 
noScoreUpdate:
     pop dx
      ret 0
updateScore ENDP

; _------------------------------- END OF CODE ---------------------------------
END main
