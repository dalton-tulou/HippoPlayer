����                                        *******************************************************************************
*                       External FQuadrascope for HippoPlayer
*				By K-P Koljonen
*******************************************************************************
* Requires kick2.0+!

 	incdir	include:
	include	exec/exec_lib.i
	include	exec/ports.i
	include	exec/types.i
	include	graphics/graphics_lib.i
	include	graphics/rastport.i
	include	intuition/intuition_lib.i
	include	intuition/intuition.i
	include	dos/dosextens.i
	include	mucro.i
	incdir
	include	asm:pt/kpl_offsets.s

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
	
WIDTH	=	320/2	* Drawing dimensions
HEIGHT	=	64/2
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

wbmessage	rs.l	1

tr1		rs.b	1
tr2		rs.b	1
tr3		rs.b	1
tr4		rs.b	1

vol1		rs	1
vol2		rs	1
vol3		rs	1
vol4		rs	1

omabitmap	rs.b	bm_SIZEOF
size_var	rs.b	0



main
	lea	var_b,a5
	move.l	4.w,a6
	move.l	a6,(a5)

	bsr.w	getwbmessage

	sub.l	a1,a1
	lob	FindTask
	move.l	d0,owntask(a5)

	lea	intuiname(pc),a1
	lore	Exec,OldOpenLibrary
	move.l	d0,_IntuiBase(a5)

	lea 	gfxname(pc),a1		
	lob	OldOpenLibrary
	move.l	d0,_GFXBase(a5)

*** Try to find HippoPlayer's port, add 1 to hip_opencount
*** Protect this phase with Forbid()-Permit()!

	lob	Forbid
	lea	portname(pc),a1
	lob	FindPort
	move.l	d0,port(a5)
	beq.w	exit
	move.l	d0,a0
	addq.b	#1,hip_opencount(a0)	* We are using the port now!
	lob	Permit

	bsr.w	getscreendata

*** Open our window
	lea	winstruc,a0
	lore	Intui,OpenWindow
	move.l	d0,windowbase(a5)
	beq.w	exit
	move.l	d0,a0
	move.l	wd_RPort(a0),rastport(a5)
	move.l	wd_UserPort(a0),userport(a5)

	move.l	rastport(a5),a1
	moveq	#1,d0
	lore	GFX,SetAPen

*** Draw some gfx

plx1	equr	d4
plx2	equr	d5
ply1	equr	d6
ply2	equr	d7
 
 
	moveq   #7,plx1
	move    #172,plx2
	moveq   #13,ply1
	moveq   #47,ply2
	add	windowleft(a5),plx1
	add	windowleft(a5),plx2
	add	windowtop(a5),ply1
	add	windowtop(a5),ply2
	move.l	rastport(a5),a1
	bsr	laatikko1


*** Initialize our bitmap structure

	lea	omabitmap(a5),a0
	moveq	#1,d0			* depth
	move	#WIDTH,d1		* width
	move	#HEIGHT,d2		* heigth (turva-alue)
	lore	GFX,InitBitMap
	move.l	#buffer1,omabitmap+bm_Planes(a5)

	move.l	#buffer1+2*WIDTH/8,draw1(a5)	* Buffer pointers for drawing
	move.l	#buffer2+2*WIDTH/8,draw2(a5)

	bsr.w	voltab

	move.l	owntask(a5),a1		* Set our task to low priority
	moveq	#-30,d0
;	moveq	#0,d0
	lore	Exec,SetTaskPri
	move.l	d0,oldpri(a5)		* Store the old priority

*** Main loop

loop	move.l	_GFXBase(a5),a6		* Wait...
	lob	WaitTOF


	move.l	port(a5),a0		* Check if HiP is playing
	tst.b	hip_quit(a0)
	bne.b	.x
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
	
.x	move.l	owntask(a5),a1		* Restore the old priority
	move.l	oldpri(a5),d0
	lore	Exec,SetTaskPri

exit

*** Exit program
	
	move.l	port(a5),d0		* IMPORTANT! Subtract 1 from
	beq.b	.uh0			* hip_opencount when exiting
	move.l	d0,a0
	subq.b	#1,hip_opencount(a0)
.uh0
	move.l	windowbase(a5),d0
	beq.b	.uh1
	move.l	d0,a0
	lore	Intui,CloseWindow
.uh1
	move.l	_IntuiBase(a5),d0
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



***** Get info about screen we're running on

getscreendata
	move.l	(a5),a0
	cmp	#37,LIB_VERSION(a0)
	bhs.b	.new
	rts
.new

*** Get some data about the default public screen
	sub.l	a0,a0
	lore	Intui,LockPubScreen  * The only kick2.0+ function in this prg!
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

	move.l	d7,a1
	sub.l	a0,a0
	lob	UnlockPubScreen
	rts



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
	cmp.b	#33,hip_playertype(a0)
	beq.b	.1
	cmp.b	#49,hip_playertype(a0)
	beq.b	.2
	bra.b	.3
.1	bsr.w	quadrascope
	bsr.b	mirror
	bra.b	.3
.2	bsr.w	multiscope
	bsr.b	mirror
.3

	popm	all


	movem.l	draw1(a5),d0/d1		* Doublebuffering
	exg	d0,d1
	movem.l	d0/d1,draw1(a5)

	lea	omabitmap(a5),a0	* Set the bitplane pointer so bitmap 
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

	move.l	port(a5),a2
	cmp.b	#49,hip_playertype(a2)
	bne.b	.ee
	addq	#5,d0
.ee
	lore	GFX,BltBitMapRastPort
	rts




mirror
*** Mirrorfill
	lore	GFX,OwnBlitter
	lob	WaitBlit
	move.l	draw1(a5),a0
	lea	$dff000,a2
	move.l	a0,$50(a2)	* A
	lea	20(a0),a1
	move.l	a1,$48(a2)	* C
	move.l	a1,$54(a2)	* D
	moveq	#0,d0
	move	d0,$60(a2)	* C
	move	d0,$64(a2)	* A
	move	d0,$66(a2)	* D
	moveq	#-1,d0
	move.l	d0,$44(a2)
	move.l	#$0b5a0000,$40(a2)	* D = A not C
	move	#15*64+10,$58(a2)	
	lea	31*20(a0),a1		* kopioidaan
	lob	WaitBlit
	movem.l	a0/a1,$50(a2)
	move	#-40,$66(a2)	* D
	move.l	#$09f00000,$40(a2)
	move	#16*64+10,$58(a2)	
	lob	WaitBlit
	lob	DisownBlitter
	rts
	


quadrascope
	move.l	port(a5),a3
	move.l	hip_PTch1(a3),a3
	move.l	draw1(a5),a0
	lea	-15(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch2(a3),a3
	move.l	draw1(a5),a0
	lea	-10(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch3(a3),a3
	move.l	draw1(a5),a0
	lea	-5(a0),a0
	bsr.b	.scope

	move.l	port(a5),a3
	move.l	hip_PTch4(a3),a3
	move.l	draw1(a5),a0
;	bsr.b	.scope
;	rts

.scope
	move.l	PTch_loopstart(a3),d0
	beq.b	.halt
	move.l	PTch_start(a3),d1
	bne.b	.jolt
.halt	rts

.jolt	
	move.l	d0,a4
	move.l	d1,a1

	move	PTch_length(a3),d5
	move	PTch_replen(a3),d4

	move.l	port(a5),a2
	moveq	#0,d1
	move.b	hip_mainvolume(a2),d1
	mulu	PTch_volume(a3),d1
	lsr	#6,d1

	tst	d1
	bne.b	.heee
	moveq	#1,d1
.heee	subq	#1,d1
	add	d1,d1
	lsl.l	#8,d1
	lea	mtab,a2
	add.l	d1,a2


	moveq	#0,d1
	moveq	#40/8-1,d7
	moveq	#1,d0
	moveq	#0,d6


drlo	

sco	macro
	move	d6,d2
	move.b	(a1)+,d2
	add	d2,d2
	move	(a2,d2),d3
	or.b	d0,(a0,d3)

	ifne	\2
	add.b	d0,d0
	endc
	
	ifne	\1
	subq	#2,d5
	bpl.b	hm\2	* $6a04
	move	d4,d5
	move.l	a4,a1
hm\2
	endc
	endm

	sco	0,1
	sco	1,2
	sco	0,3
	sco	1,4
	sco	0,5
	sco	1,6
	sco	0,7
	sco	1,0

	moveq	#1,d0
	sub	d0,a0
	sub	d0,a3
	dbf	d7,drlo
	rts



*** stereoscope

multiscope
	move.l	port(a5),a1
	move.l	hip_ps3mleft(a1),a1
	move.l	draw1(a5),a0
	lea	19/2(a0),a0
	bsr.b	.h

	move.l	port(a5),a1
	move.l	hip_ps3mright(a1),a1
	move.l	draw1(a5),a0
	lea	39/2(a0),a0
.h

	move.l	port(a5),a2
	move.l	hip_ps3moffs(a2),d5
	move.l	hip_ps3mmaxoffs(a2),d4
	lea	multab,a2

	moveq	#80/8-1-1,d7
	moveq	#1,d0
	move	#$80,d6




mou	macro
	move	d6,d2
	add.b	(a1,d5.l),d2
	bpl.b	.ok\1
	not.b	d2
.ok\1

	lsr.b	#3,d2
	add	d2,d2
	move	(a2,d2),d2
	or.b	d0,(a0,d2)

	add.b	d0,d0
	addq.l	#1,d5
	and.l	d4,d5
	endm

	
.drlo	
	mou	1
	mou	2
	mou	3
	mou	4
	mou	5
	mou	6
	mou	7
	mou	8

	moveq	#1,d0
	sub	d0,a0
	dbf	d7,.drlo
	rts




******* Filled quadrascope
voltab
	lea	mtab,a0
	moveq	#$40-1,d3
	moveq	#0,d2
.olp2q	moveq	#0,d0
	move	#256-1,d4
.olp1q	move	d0,d1
	ext	d1
	muls	d2,d1
	asr	#8,d1
	asr	#1,d1
	tst	d1
	bmi.b	.mee
	moveq	#31/2,d5
	sub	d1,d5
	move	d5,d1
	sub	#32/2,d1
.mee	add	#32/2,d1
	mulu	#40/2,d1
	add	#39/2,d1
	move	d1,(a0)+
	addq	#1,d0
	dbf	d4,.olp1q
	addq	#1,d2
	dbf	d3,.olp2q
	rts



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
winsiz	dc	180,52	* x,y size
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

.t	dc.b	"F.QuadraScope",0

intuiname	dc.b	"intuition.library",0
gfxname		dc.b	"graphics.library",0
dosname		dc.b	"dos.library",0
portname	dc.b	"HiP-Port",0
 even






 	section	udnm,bss_p

var_b		ds.b	size_var
mtab		ds.b	64*256*2

	section	hihi,bss_c

buffer1	ds.b	WIDTH/8*RHEIGHT
buffer2	ds.b	WIDTH/8*RHEIGHT

 end
