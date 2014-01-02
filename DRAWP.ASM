.MODEL large

INCLUDE GAME.INC ; for data
INCLUDE SPRITES.INC
INCLUDE DRAWP.INC


PUBLIC drawPlayer, drawArray, drawObstacles, drawBeam, drawEnd, drawBegin, drawNumber, drawScore
.CODE

drawPlayer PROC FAR
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
drawArray PROC FAR
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
	mov ax, [bp+6][0]
	mov di, ax
	;array
	mov ax, @data
	mov ds, ax
	mov ax, [bp+6][2]
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

drawObstacles PROC FAR
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
	mov	ax, [obstacles][bx]

	cmp	ax, 0
	jne	nextobstacle
	jmp	enddrawobstacles

nextobstacle:
      mov   [drawCheck], 0
      mov   di, offset screenBuffer
	;pos x
	add 	di, [obstacles][bx]
	;pos y
	mov 	ax, [obstacles][bx+2]
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
	mov	cx, [levelObst][bx]
	pop 	bx
@@:	
      call checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNextSub
	mov es:[di], al
	add	di, SCREENW
	loop @B
      jmp   skip
toNextSub:
      jmp   toNext
skip:
	;rechts
	push 	bx
	xor 	bx, bx
      xor   dx, dx
	mov   bx, [level]
	mov	cx, [levelObst][bx]
      pop   bx
      mov   dx, SCREENW
      sub   dx, [obstacles][bx]      
      cmp   cx, dx
      jl @F
      mov   cx, dx
      mov   [drawCheck], 1
@@:
      call checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNext
	mov es:[di], al
	inc	di
	loop @B

	;omhoog
      cmp   [drawCheck], 1
      je    notUp
	push 	bx
	xor 	bx, bx
	mov   bx, [level]
	mov	cx, [levelObst][bx]
	pop 	bx
@@:
      call checkCollide
      cmp   dx, 1 ;check if deleted
      je    toNext
	mov es:[di], al
	sub di, SCREENW
	loop @B
      jmp   next
notUp:
      push  bx
      push  ax
      xor   bx,bx
      mov   bx, [level]
      mov   dx, SCREENW
      mov   ax, [levelObst][bx]
      mul   dx
      sub   di, ax
      dec   di
      pop   ax
      pop   bx
next:
      xor   dx,dx
	;links
	push 	bx
	xor 	bx, bx
      xor   dx, dx
	mov   bx, [level]
	mov	cx, [levelObst][bx]
      pop   bx
      mov   dx, SCREENW
      sub   dx, [obstacles][bx] 
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
	mov 	ax, [obstacles][bx]
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

drawBeam PROC FAR
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
	mov	ax, [beams][bx]
	cmp 	ax,0
	je	done


	mov	di, offset screenBuffer
      ;pos x
	add	di, [beams][bx]

      ;determine the length of the beam to prevent it being drawn on the opposite
      ;side of the screen
	mov   cx, SCREENW
      sub   cx, [beams][bx]
      cmp   cx, BEAMLENGTH
      jle    @F
      mov   cx, BEAMLENGTH
@@:

      ;pos y
	add 	bx, 2
	mov	ax, [beams][bx]
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

;Draws a full red screen
drawEnd PROC FAR
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

;Draws the beginning UI
drawBegin PROC FAR
      push ax
      
      ;first half of the text
      mov ax, offset asteroid_field
      push ax
      mov ax, MIDDLE
      push ax
      call drawArray
      ;second half
      mov ax, offset asteroid_field2
      push ax
      mov ax, MIDDLE + 32
      push ax
      call drawArray

      ;press enter text
      mov ax, offset press_enter
      push ax
      mov ax, PRESS_ENTER_PLACE
      push ax
      call drawArray
      ;We need to call this since we are not in the renderWorld procedure
      call 	updateScreen

      pop ax      
      ret 0
drawBegin ENDP

;draws a certain number
drawNumber PROC FAR
	push bp
	mov bp, sp

      push ax
      push dx
      push cx

      mov ax, [bp + 6][0] ;offset
      mov dx, SCORE_MARGIN
      mul dx
      mov dx, SCORE_PLACE
      sub dx, ax
      xor ax, ax
      mov ax, [bp + 6][2] ;number to print

      cmp ax, 0
      jne @F
      mov ax, offset zero_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 1
      jne @F
      mov ax, offset one_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 2
      jne @F
      mov ax, offset two_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:       
      cmp ax, 3
      jne @F
      mov ax, offset three_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 4
      jne @F
      mov ax, offset four_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 5
      jne @F
      mov ax, offset five_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 6
      jne @F
      mov ax, offset six_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 7
      jne @F
      mov ax, offset seven_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 8
      jne @F
      mov ax, offset eight_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
@@:
      cmp ax, 9
      jne endDrawNumber
      mov ax, offset nine_num
      push ax
      push dx
      call drawArray
      jmp endDrawNumber
    
endDrawNumber:
      pop cx  
      pop dx
      pop ax
      mov sp, bp
	pop bp
      ret 4
drawNumber ENDP

drawScore PROC FAR

        push ax
        push bx
        push dx
        push cx

        mov bx,0

        mov ax, [score]
@@:
        mov dx, 0
        mov cx, 10
        div cx
        push dx
        push bx
        call drawNumber
        inc bx
        cmp ax,0
        jle done
        jmp @B

done:
        pop cx
        pop dx
        pop bx
        pop ax
        ret 0

drawScore ENDP

END
