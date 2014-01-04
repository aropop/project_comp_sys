;Game data and macros

;Data

externdef position:WORD, obstacles:WORD, beams:WORD, dead:BYTE, endcounter:BYTE, screenBuffer:BYTE, level:WORD, levelObst:WORD, drawCheck:BYTE, score:WORD, started:BYTE
externdef checkCollide:FAR, updateScreen:FAR

;Macro's
SCREENW		equ 320
SCREENH		equ 200
PLAYERH		equ 20
PLAYERW		equ 10
PLAYERSTARTY	equ 0
PLAYERX		equ 12

MAXOBSTACLES 	equ 25
MAXBEAMS          equ 50

OBSTACLESPAWNX 	equ 319
OBSTACLEW	      equ 10
TIMEBETWEENOBST   equ 10

TIMEBETWEENBEAMS  equ 3	
BEAMLENGTH        equ 4

TIMEBETWEENLEVELS equ 1000
TIMETOSTART       equ 10

ENEMYSCORE	      equ 3
BULLETPENALTY	equ -1


SCORE_PLACE       equ 2950
SCORE_MARGIN      equ 10
OBSTACLECOLOR	equ 60
BEAMCOLOR         equ 34
ENDCOLOR	      equ 64

AMOUNTPIXELS	equ 64000
