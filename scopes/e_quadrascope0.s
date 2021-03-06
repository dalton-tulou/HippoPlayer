����                                        *******************************************************************************
*                       External quadrascope for HippoPlayer
*				By K-P Koljonen
*******************************************************************************

*** Includes:

 	incdir	include:
	include	exec/exec_lib.i
	include	exec/ports.i
	include	exec/types.i
	include	graphics/graphics_lib.i
	include	graphics/rastport.i
	include	intuition/intuition_lib.i
	include	intuition/intuition.i
	include	dos/dosextens.i
	incdir

*** Some useful macros

lob	macro
	jsr	_LVO\1(a6)
	endm

lore	macro
	ifc	"\1","Exec"
	ifd	_ExecBase
	ifeq	_ExecBase
	move.l	(a5),a6
	else
	move.l	_ExecBase(a5),a6
	endc
	else
	move.l	4.w,a6
	endc
	else
	move.l	_\1Base(a5),a6
	endc
	jsr	_LVO\2(a6)
	endm

pushm	macro
	ifc	"\1","all"
	movem.l	d0-a6,-(sp)
	else
	movem.l	\1,-(sp)
	endc
	endm

popm	macro
	ifc	"\1","all"
	movem.l	(sp)+,d0-a6
	else
	movem.l	(sp)+,\1
	endc
	endm

push	macro
	move.l	\1,-(sp)
	endm

pop	macro
	move.l	(sp)+,\1
	endm



*** HippoPlayer's port:

	STRUCTURE	HippoPort,MP_SIZE
	LONG		hip_private1	* Private..
	APTR		hip_kplbase	* kplbase address
	WORD		hip_reserved0	* Private..
	BYTE		hip_quit
	BYTE		hip_opencount	* Open count
	BYTE		hip_mainvolume	* Main volume, 0-64
	BYTE		hip_play	* If non-zero, HiP is playing
	BYTE		hip_playertype 	* 33 = Protracker, 49 = PS3M. 
	*** Protracker ***
	BYTE		hip_reserved2
	APTR		hip_PTch1	* Protracker channel data for ch1
	APTR		hip_PTch2	* ch2
	APTR		hip_PTch3	* ch3
	APTR		hip_PTch4	* ch4
	*** PS3M ***
	APTR		hip_ps3mleft	* Buffer for the left side
	APTR		hip_ps3mright	* Buffer for the right side
	LONG		hip_ps3moffs	* Playing position
	LONG		hip_ps3mmaxoffs	* Max value for hip_ps3moffs

	BYTE		hip_PTtrigger1
	BYTE		hip_PTtrigger2
	BYTE		hip_PTtrigger3
	BYTE		hip_PTtrigger4

	LABEL		HippoPort_SIZEOF 

	*** PT channel data block
	STRUCTURE	PTch,0
	LONG		PTch_start	* Start address of sample
	WORD		PTch_length	* Length of sample in words
	LONG		PTch_loopstart	* Start address of loop
	WORD		PTch_replen	* Loop length in words
	WORD		PTch_volume	* Channel volume
	WORD		PTch_period	* Channel period
	WORD		PTch_private1	* Private...

*** Dimensions:

WIDTH	=	320	
HEIGHT	=	64
RHEIGHT	=	HEIGHT+4

*** Variables:

	rsreset
_ExecBase	rs.l	1
_GFXBase	rs.l	1
_IntuiBase	rs.l	1
port		rs.l	1
owntask		rs.l	1
screenlock	rs.l	1
oldpri		rs.l	1
windowbase	rs.l	1
rastport	rs.l	1
userport	rs.l	1
windowtop	rs	1
windowtopb	rs	1
windowright	rs	1
windowleft	rs	1
windowbottom	rs	1
draw1		rs.l	1
draw2		rs.l	1
icounter	rs	1
icounter2	rs	1

tr1		rs.b	1
tr2		rs.b	1
tr3		rs.b	1
tr4		rs.b	1

vol1		rs	1
vol2		rs	1
vol3		rs	1
vol4		rs	1

wbmessage	rs.l	1

omabitmap	rs.b	bm_SIZEOF
size_var	rs.b	0

*** Program

main	lea	var_b,a5		* Store execbase
	move.l	4.w,a6
	move.l	a6,(a5)

	bsr.w	getwbmessage

	lea	intuiname(pc),a1	* Open libs
	lore	Exec,OldOpenLibrary
	move.l	d0,_IntuiBase(a5)

	lea 	gfxname(pc),a1		
	lob	OldOpenLibrary
	move.l	d0,_GFXBase(a5)

*** Try to find HippoPlayer's port. If succesfull, add 1 to hip_opencount
*** indicating we are using the information in the port.
*** Protect this phase with Forbid()-Permit()!

	lob	Forbid
	lea	portname(pc),a1
	lob	FindPort
	move.l	d0,port(a5)
	beq.w	exit
	move.l	d0,a0
	addq.b	#1,hip_opencount(a0)	* We are using the port now!
	lob	Permit

*** Get some info about the screen we're running on

	bsr.w	getscreendata

*** Open our window

	lea	winstruc,a0
	lore	Intui,OpenWindow
	move.l	d0,windowbase(a5)
	beq.w	exit
	move.l	d0,a0
	move.l	wd_RPort(a0),rastport(a5)	* Store rastport and userport
	move.l	wd_UserPort(a0),userport(a5)

*** Draw some gfx

plx1	equr	d4
plx2	equr	d5
ply1	equr	d6
ply2	equr	d7
 
	moveq   #7,plx1
	move    #332,plx2
	moveq   #13,ply1
	moveq #80,ply2
	add	windowleft(a5),plx1
	add	windowleft(a5),plx2
	add	windowtop(a5),ply1
	add	windowtop(a5),ply2
	move.l	rastport(a5),a1
	bsr.w	piirra_loota2a

*** Initialize the bitmap structure

	lea	omabitmap(a5),a0
	moveq	#1,d0			* depth
	move	#WIDTH,d1		* width
	move	#HEIGHT,d2		* height 
	lore	GFX,InitBitMap
	move.l	#buffer1,omabitmap+bm_Planes(a5) * Plane pointer

	move.l	#buffer1+2*WIDTH/8,draw1(a5)	* Buffer pointers for drawing
	move.l	#buffer2+2*WIDTH/8,draw2(a5)

*** Calculate some stuff

	bsr.w	voltab
	bsr.w	mwotta

*** Set task priority to -30 to prevent messing up with other programs

	move.l	owntask(a5),a1		
	moveq	#-30,d0
	lore	Exec,SetTaskPri
	move.l	d0,oldpri(a5)		* Store the old priority

*** Main loop begins here

loop	move.l	_GFXBase(a5),a6		* Wait a while..
	lob	WaitTOF

	move.l	port(a5),a0		* Check if HiP is playing
	tst.b	hip_quit(a0)
	bne.b	exi
	tst.b	hip_play(a0)
	beq.b	.oh

*** See if we should actually update the window.
	move.l	_IntuiBase(a5),a1
	move.l	ib_FirstScreen(a1),a1
	move.l	windowbase(a5),a0	
	cmp.l	wd_WScreen(a0),a1	* Is our screen on top?
	beq.b	.yes
	tst	sc_TopEdge(a1)	 	* Some other screen is partially on top 
	beq.b	.oh		 	* of our screen?
.yes

	bsr.w	dung			* Do the scope
.oh
	move.l	userport(a5),a0		* Get messages from IDCMP
	lore	Exec,GetMsg
	tst.l	d0
	beq.b	loop
	move.l	d0,a1

	move.l	im_Class(a1),d2		
	move	im_Code(a1),d3
	lob	ReplyMsg
	cmp.l	#IDCMP_MOUSEBUTTONS,d2	* Right mousebutton pressed?
	bne.b	.xy
	cmp	#MENUDOWN,d3
	beq.b	.x
.xy	cmp.l	#IDCMP_CLOSEWINDOW,d2	* Should we exit?
	bne.b	loop			* No. Keep loopin'
.x
	
exi	move.l	owntask(a5),a1		* Restore the old priority
	move.l	oldpri(a5),d0
	lore	Exec,SetTaskPri

exit

*** Exit program
	
	move.l	port(a5),d0		* IMPORTANT! Subtract 1 from
	beq.b	.uh0			* hip_opencount when the port is not
	move.l	d0,a0			* needed anymore
	subq.b	#1,hip_opencount(a0)
.uh0
	move.l	windowbase(a5),d0	* Close the window
	beq.b	.uh1
	move.l	d0,a0
	lore	Intui,CloseWindow
.uh1
	move.l	_IntuiBase(a5),d0	* And the libs
	bsr.b	closel
	move.l	_GFXBase(a5),d0
	bsr.b	closel

	bsr.w	replywbmessage

	moveq	#0,d0			* No error
	rts
	
closel  beq.b   .huh
        move.l  d0,a1
        lore    Exec,CloseLibrary
.huh    rts


***** Get some info about screen we're running on

getscreendata
	move.l	(a5),a0			* Running kick2.0 or newer?
	cmp	#37,LIB_VERSION(a0)
	bhs.b	.new		
	rts				
.new					* Yes.
	
	sub.l	a0,a0			* Default public screen
	lore	Intui,LockPubScreen  	* The only kick2.0+ function
	move.l	d0,d7
	beq.b	exit

	move.l	d0,a0
	move.b	sc_BarHeight(a0),windowtop+1(a5) * Palkin korkeus
	move.b	sc_WBorBottom(a0),windowbottom+1(a5)
	move.b	sc_WBorTop(a0),windowtopb+1(a5)
	move.b	sc_WBorLeft(a0),windowleft+1(a5)
	move.b	sc_WBorRight(a0),windowright+1(a5)

	move	windowtopb(a5),d0
	add	d0,windowtop(a5)

	subq	#4,windowleft(a5)		* saattaa menn� negatiiviseksi
	subq	#4,windowright(a5)
	subq	#2,windowtop(a5)
	subq	#2,windowbottom(a5)

	sub	#10,windowtop(a5)
	bpl.b	.o
	clr	windowtop(a5)
.o

	move	windowtop(a5),d0	* Adjust the window size
	add	d0,winstruc+6		
	move	windowleft(a5),d1
	add	d1,winstruc+4		
	add	d1,winsiz
	move	windowbottom(a5),d3
	add	d3,winsiz+2

	move.l	d7,a1			* Unlock it. Let's hope it doesn't
	sub.l	a0,a0			* go anywhere before we open our
	lob	UnlockPubScreen		* window.
	rts


*** Draw a bevel box

piirra_loota2a

** bevelboksit, reunat kaks pixeli�

laatikko1
	moveq	#1,d3
	moveq	#2,d2

	move.l	a1,a3
	move	d2,a4
	move	d3,a2

** valkoset reunat

	move	a2,d0
	move.l	a3,a1
	lore	GFX,SetAPen

	move	plx2,d0		* x1
	subq	#1,d0		
	move	ply1,d1		* y1
	move	plx1,d2		* x2
	move	ply1,d3		* y2
	bsr.w	drawli

	move	plx1,d0		* x1
	move	ply1,d1		* y1
	move	plx1,d2
	addq	#1,d2
	move	ply2,d3
	bsr.w	drawli
	
** mustat reunat

	move	a4,d0
	move.l	a3,a1
	lob	SetAPen

	move	plx1,d0
	addq	#1,d0
	move	ply2,d1
	move	plx2,d2
	move	ply2,d3
	bsr.b	drawli

	move	plx2,d0
	move	ply2,d1
	move	plx2,d2
	move	ply1,d3
	bsr.b	drawli

	move	plx2,d0
	subq	#1,d0
	move	ply1,d1
	addq	#1,d1
	move	plx2,d2
	subq	#1,d2
	move	ply2,d3
	bsr.b	drawli

looex	moveq	#1,d0
	move.l	a3,a1
	jmp	_LVOSetAPen(a6)



drawli	cmp	d0,d2
	bhi.b	.e
	exg	d0,d2
.e	cmp	d1,d3
	bhi.b	.x
	exg	d1,d3
.x	move.l	a3,a1
	move.l	_GFXBase(a5),a6
	jmp	_LVORectFill(a6)





*** Draw the scope

dung
	move.l	_GFXBase(a5),a6		* Grab the blitter
	lob	OwnBlitter
	lob	WaitBlit

	move.l	draw2(a5),$dff054	* Clear the drawing area
	move	#0,$dff066
	move.l	#$01000000,$dff040
	move	#HEIGHT*64+WIDTH/16,$dff058

	lob	DisownBlitter		* Free the blitter

	pushm	all
	move.l	port(a5),a0
	cmp.b	#33,hip_playertype(a0)	* Protracker?
	beq.b	.1
	cmp.b	#49,hip_playertype(a0)	* PS3M?
	beq.b	.2
	bra.b	.3
.1	bsr.b	quadrascope
	bsr.w	lever
	bra.b	.3
.2	bsr.w	multiscope
.3	popm	all


*** Doublebuffering. 
* Bad: needs mem for two buffers (not that much though)
* Good: fast (blitter and cpu working simultaneously)

	movem.l	draw1(a5),d0/d1		* Switch the buffers
	exg	d0,d1
	movem.l	d0/d1,draw1(a5)

	lea	omabitmap(a5),a0	* Set the bitplane pointer
	move.l	d1,bm_Planes(a0)

;	lea	omabitmap(a5),a0	* Copy from bitmap to rastport
	move.l	rastport(a5),a1
	moveq	#0,d0		* source x,y
	moveq	#0,d1
	moveq	#10,d2		* dest x,y
	moveq	#15,d3
	add	windowleft(a5),d2
	add	windowtop(a5),d3
	move	#$c0,d6		* minterm a->d
	move	#WIDTH,d4	* x-size
	move	#HEIGHT,d5	* y-size

	move.l	port(a5),a2		* Shift a bit if PS3M
	cmp.b	#49,hip_playertype(a2)
	bne.b	.ee
	addq	#4,d0
.ee
	lore	GFX,BltBitMapRastPort
	rts

*** The scope routine

quadrascope
	move.l	port(a5),a3
	move.l	hip_PTch1(a3),a3	* Channel 1 data
	move.l	draw1(a5),a0		
	lea	-30(a0),a0		* Position to draw to
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch2(a3),a3
	move.l	draw1(a5),a0
	lea	-20(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch3(a3),a3
	move.l	draw1(a5),a0
	lea	-10(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch4(a3),a3
	move.l	draw1(a5),a0
;	bsr.b	.scope
;	rts

.scope
	move.l	PTch_loopstart(a3),d0	* Always check these to avoid
	beq.b	.halt			* enforcer hits!
	move.l	PTch_start(a3),d1
	bne.b	.jolt
.halt	rts

.jolt	
	move.l	d0,a4				* Loop start
	move.l	d1,a1				* Sample start

	move	PTch_length(a3),d5		* Get sample length and 
	move	PTch_replen(a3),d4		* loop length

	move.l	port(a5),a2
	moveq	#0,d1
	move.b	hip_mainvolume(a2),d1	* (Main volume * sample volume)/64
	mulu	PTch_volume(a3),d1	
	lsr	#6,d1

	tst	d1			* Get the correct position in the
	bne.b	.heee			* table... 
	moveq	#1,d1
.heee	subq	#1,d1
	add	d1,d1
	lsl.l	#8,d1
	lea	mtab,a2
	add.l	d1,a2

	lea	-40(a0),a3		* Position 2 one pixel above position 1

	moveq	#80/8-1,d7		* Draw 80 pixels
	moveq	#1,d0			* Pixel register
	moveq	#0,d6

drlo	

*** Inner loop macro

sco	macro
	move	d6,d2		* Clear word
	move.b	(a1)+,d2	* Get one byte sample data
	add	d2,d2		* Multiply by two 
	move	(a2,d2),d3	* Get a scaled value from the volume table
	or.b	d0,(a3,d3)	* Plot pixel	
	or.b	d0,(a0,d3)	* Plot another pixel

	ifne	\2	
	add.b	d0,d0		* Roll left the pixel register
	endc
	
	ifne	\1
	subq	#2,d5		* End of the sample?
	bpl.b	hm\2
	move	d4,d5		* Then loop. 
	move.l	a4,a1
hm\2
	endc
	endm


	sco	0,1	* 0 = Don't check if the sample ended, 1 = temp label
	sco	1,2		
	sco	0,3
	sco	1,4
	sco	0,5
	sco	1,6
	sco	0,7
	sco	1,0	* 0 = ..., 0 = roll the pixel register

	moveq	#1,d0		* Reset the pixel register
	sub	d0,a0		* Move 8 pixels left in the bitplane
	sub	d0,a3		* ...
	dbf	d7,drlo		* Loop..
	rts



*** Stereoscope for PS3M

multiscope
	move.l	port(a5),a1
	move.l	hip_ps3mleft(a1),a1
	move.l	draw1(a5),a0
	lea	19(a0),a0
	bsr.b	.h

	move.l	port(a5),a1
	move.l	hip_ps3mright(a1),a1
	move.l	draw1(a5),a0
	lea	39(a0),a0
.h

	move.l	port(a5),a2
	move.l	hip_ps3moffs(a2),d5
	move.l	hip_ps3mmaxoffs(a2),d4
	lea	multab,a2
		
	moveq	#160/8-1-1,d7
	moveq	#1,d0
	move	#$80,d6

	
.drlo	
 
 rept 8
	move	d6,d2
	add.b	(a1,d5.l),d2
	lsr.b	#2,d2
	add	d2,d2
	move	(a2,d2),d2
	or.b	d0,-40(a0,d2)
	or.b	d0,(a0,d2)
	add.b	d0,d0

	addq.l	#1,d5
	and.l	d4,d5
 endr
	
	moveq	#1,d0
	sub	d0,a0
	dbf	d7,.drlo
	rts


*** Calculate volumetable for quadrascope

voltab
	lea	mtab,a0
	moveq	#$40-1,d3
	moveq	#0,d2

.olp2	moveq	#0,d0
	move	#256-1,d4
.olp1	move	d0,d1
	ext	d1
	muls	d2,d1
	asr	#8,d1
	add	#32,d1
	mulu	#40,d1
	add	#39,d1
	move	d1,(a0)+
	addq	#1,d0
	dbf	d4,.olp1
	addq	#1,d2
	dbf	d3,.olp2
	rts


*** Draw volumeperiod bars

lever
	move.l	port(a5),a4
	lea	hip_PTch1(a4),a4
	moveq	#4-1,d2
	moveq	#0,d3
	move.l	draw1(a5),a2
.l	move.l	a2,a0
	move.l	(a4)+,a3
	bsr.b	dlever
	lea	10(a2),a2
	dbf	d2,.l
	rts
	

* 907-108
dlever
	cmp	#2,PTch_length(a3)
	bls.b	.h
	moveq	#0,d1
	move	PTch_period(a3),d1
	beq.b	.h
	sub	#108,d1
	lsl	#1,d1
	divu	#27,d1		* 0-59

	lea	multab,a1
	add	d1,d1
	add	(a1,d1),a0

	move.l	port(a5),a1
	moveq	#0,d0
	move.b	hip_mainvolume(a1),d0
	mulu	PTch_volume(a3),d0

	lsr	#6,d0
	bne.b	.pad
	moveq	#1,d0
.pad	
	lsl	#3,d0
	subq	#8,d0
	bpl.b	.ojdo
	moveq	#0,d0
.ojdo
	lea	wotta,a1
	movem.l	(a1,d0),d0/d1

	pushm	d2/d3

	and.l	#$55555555,d0
	and.l	#$55555555,d1
	move.l	d0,d2
	move.l	d1,d3
	roxl.l	#1,d3
	roxl.l	#1,d2

	or.l	d0,(a0)+
	or.l	d1,(a0)
	or.l	d2,40-4(a0)
	or.l	d3,40(a0)
	or.l	d0,80-4(a0)
	or.l	d1,80(a0)
	or.l	d2,120-4(a0)
	or.l	d3,120(a0)

	popm	d2/d3
.h	rts

*** Calculate the bars
 
mwotta	lea	wotta,a0
	moveq	#1,d0
.lpew	move	d0,d1
	moveq	#0,d2
	moveq	#0,d3
.lpw	bset	#31,d2
	ror.l	#1,d2
	bpl.b	.now
	bset	#31,d3
	ror.l	#1,d3
.now	subq	#1,d1
	bne.b	.lpw
	rol.l	#1,d2
	rol.l	#1,d3
	move.l	d2,(a0)+
	move.l	d3,(a0)+
	addq	#1,d0
	cmp	#64+1,d0
	bne.b	.lpew
	rts

*** Multiplication table for Y

multab
aa set 0
	rept	HEIGHT
	dc	aa
aa set aa+WIDTH/8
	endr





**
* Workbench viestit
**
getwbmessage
	sub.l	a1,a1
	lore	Exec,FindTask
	move.l	d0,owntask(a5)

	move.l	d0,a4			* Vastataan WB:n viestiin, jos on.
	tst.l	pr_CLI(a4)
	bne.b	.nowb
	lea	pr_MsgPort(a4),a0
	lob	WaitPort
	lea	pr_MsgPort(a4),a0
	lob	GetMsg
	move.l	d0,wbmessage(a5)	
.nowb	rts

replywbmessage
	move.l	wbmessage(a5),d3
	beq.b	.nomsg
	lore	Exec,Forbid
	move.l	d3,a1
	lob	ReplyMsg
.nomsg	rts


*******************************************************************************
* Window

wflags set WFLG_SMART_REFRESH!WFLG_DRAGBAR!WFLG_CLOSEGADGET!WFLG_DEPTHGADGET
wflags set wflags!WFLG_RMBTRAP
idcmpflags = IDCMP_CLOSEWINDOW!IDCMP_MOUSEBUTTONS


winstruc
	dc	110,85	* x,y position
winsiz	dc	340,85	* x,y size
	dc.b	2,1	
	dc.l	idcmpflags
	dc.l	wflags
	dc.l	0
	dc.l	0	
	dc.l	.t	* title
	dc.l	0
	dc.l	0	
	dc	0,640	* min/max x
	dc	0,256	* min/max y
	dc	WBENCHSCREEN
	dc.l	0

.t	dc.b	"QuadraScope",0

intuiname	dc.b	"intuition.library",0
gfxname		dc.b	"graphics.library",0
dosname		dc.b	"dos.library",0
portname	dc.b	"HiP-Port",0
 even


 	section	udnm,bss_p

var_b		ds.b	size_var
mtab		ds.b	64*256*2
wotta		ds.b	512

	section	hihi,bss_c

buffer1	ds.b	WIDTH/8*RHEIGHT
buffer2	ds.b	WIDTH/8*RHEIGHT

 end
