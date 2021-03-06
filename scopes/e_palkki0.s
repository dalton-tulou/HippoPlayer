����  $S                                    *******************************************************************************
*                           VU meter for HippoPlayer
*				By K-P Koljonen
*******************************************************************************

 	incdir	include:
	include	exec/exec_lib.i
	include	exec/execbase.i
	include	exec/ports.i
	include	exec/types.i
	include	dos/dosextens.i
	include	graphics/graphics_lib.i
	include	graphics/rastport.i
	include	intuition/intuition_lib.i
	include	intuition/intuition.i
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
	
WIDTH	=	128	* Drawing dimensions
WID8	=	WIDTH/8
HEIGHT	=	64
PLANE	=	WID8*HEIGHT

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

wbmessage	rs.l	1

omabitmap	rs.b	bm_SIZEOF
size_var	rs.b	0



main
	lea	var_b,a5
	move.l	4.w,a6
	move.l	a6,(a5)


	bsr.w	getwbmessage


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
	move    #332-192,plx2
	moveq   #13,ply1
	move	#80,ply2
	add	windowleft(a5),plx1
	add	windowleft(a5),plx2
	add	windowtop(a5),ply1
	add	windowtop(a5),ply2
	move.l	rastport(a5),a1
	bsr.w	piirra_loota2a

*** Initialize our bitmap structure

	lea	omabitmap(a5),a0
	moveq	#2,d0			* depth
	move	#WIDTH,d1		* width
	move	#HEIGHT,d2		* heigth (turva-alue)
	lore	GFX,InitBitMap
	move.l	#buffer1,omabitmap+bm_Planes(a5)
	move.l	#buffer1+PLANE,omabitmap+bm_Planes+4(a5)

	move.l	#buffer1,draw1(a5)	* Buffer pointers for drawing
	move.l	#buffer2,draw2(a5)


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
	move	#2*HEIGHT*64+WIDTH/16,$dff058

	lob	DisownBlitter		* Free the blitter

	pushm	all
	move.l	port(a5),a0
	cmp.b	#33,hip_playertype(a0)
	beq.b	.1
	cmp.b	#49,hip_playertype(a0)
	beq.b	.2
	bra.b	.3
.1	bsr.w	klonk
	bra.b	.3
.2	bsr.w	multiklonk
.3
	popm	all

	moveq	#-1,d0
	move.l	draw1(a5),a0
	lea	PLANE(a0),a0
	lea	WID8*(63-16)(a0),a0
	bsr.b	.bb
	lea	-16*WID8(a0),a0
	bsr.b	.bb
	lea	-16*WID8(a0),a0
	bsr.b	.bb
	bra.b	.bbb
.bb
	move.l	d0,(a0)
	move.l	d0,4(a0)
	move.l	d0,8(a0)
	move.l	d0,12(a0)
	rts
.bbb

	movem.l	draw1(a5),d0/d1		* Doublebuffering
	exg	d0,d1
	movem.l	d0/d1,draw1(a5)

	lea	omabitmap(a5),a0	* Set the bitplane pointer so bitmap 
	move.l	d1,bm_Planes(a0)
	add.l	#PLANE,d1
	move.l	d1,bm_Planes+4(a0)

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
	lore	GFX,BltBitMapRastPort
	rts


klonk

	move.l	port(a5),a3
	move.l	hip_PTch1(a3),a3
	move.l	draw1(a5),a6
	bsr.b	.twirl

	move.l	port(a5),a3
	move.l	hip_PTch2(a3),a3
	move.l	draw1(a5),a6
	lea	4(a6),a6
	bsr.b	.twirl

	move.l	port(a5),a3
	move.l	hip_PTch3(a3),a3
	move.l	draw1(a5),a6
	lea	8(a6),a6
	bsr.b	.twirl

	move.l	port(a5),a3
	move.l	hip_PTch4(a3),a3
	move.l	draw1(a5),a6
	lea	12(a6),a6
	bsr.b	.twirl
	rts


.twirl
	move.l	port(a5),a2
	moveq	#0,d3
	move.b	hip_mainvolume(a2),d3
	mulu	PTch_volume(a3),d3
	lsr	#6,d3

	move.l	PTch_loopstart(a3),d6
	beq.b	.halt
	move.l	PTch_start(a3),d1
	bne.b	.jolt
.halt	rts
.jolt	
	move.l	d1,a1

	move	PTch_length(a3),d4
;	move.l	PTch_start(a3),a1
	move	PTch_replen(a3),d5

	moveq	#64-1,d0
	moveq	#0,d2
	moveq	#0,d7
.d
	moveq	#0,d1
	move.b	(a1)+,d1
	bpl.b	.b
	not.b	d1
.b	mulu	d3,d1
	lsr	#6,d1
	sub	d1,d7
	bpl.b	.rr
	neg	d7
.rr
	add	d7,d2

	subq	#1,d4
	bpl.b	.h
	move	d5,d4
	move.l	d6,a1
.h
	dbf	d0,.d


* d2 = x1+x2+...xn
	lsr	#6,d2
	and	#$7f,d2
	subq	#1,d2
	bmi.b	.x


	lea	PLANE(a6),a6
	move.l	#$0ffffff0,d0
.loop	lea	-WID8(a6),a6
	move.l	d0,(a6)
	dbf	d2,.loop

.x
	rts


 
multiklonk
	move.l	port(a5),a1
	move.l	hip_ps3mleft(a1),a1
	move.l	draw1(a5),a0
	bsr.b	.h

	move.l	port(a5),a1
	move.l	hip_ps3mright(a1),a1
	move.l	draw1(a5),a0
	lea	WID8/2(a0),a0
	bsr.b	.h
	rts

.h	move.l	port(a5),a2
	move.l	hip_ps3moffs(a2),d5		* Get offset in buffers
	move.l	hip_ps3mmaxoffs(a2),d4		* Get max offset
		
	move	#64-1,d7	
	moveq	#0,d0			* X coord
	moveq	#0,d1
.drlo	
	moveq	#0,d2
	move.b	(a1,d5.l),d2		* Get data from mixing buffer
	bpl.b	.rr
	not.b	d2
.rr
;	sub.b	d2,d1
;	add	d1,d0
	add	d2,d0

	addq.l	#1,d5			* Increase buffer position
	and.l	d4,d5			* make sure it stays in the buffer

	dbf	d7,.drlo		* Loop


	lsr	#7,d0
	and	#$7f,d0
	subq	#1,d0
	bmi.b	.x

	move.l	#$0fffffff,d1
	moveq	#-16,d2

	lea	PLANE(a0),a0
.loop
	lea	-WID8(a0),a0
	movem.l	d1/d2,(a0)
	dbf	d0,.loop

.x

	rts





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
winsiz	dc	340-192,85	* x,y size
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

.t	dc.b	"VU Meter",0

intuiname	dc.b	"intuition.library",0
gfxname		dc.b	"graphics.library",0
dosname		dc.b	"dos.library",0
portname	dc.b	"HiP-Port",0
 even






 	section	udnm,bss_p

var_b		ds.b	size_var

	section	hihi,bss_c

	ds.b	PLANE	* turva
buffer1	ds.b	PLANE*2
buffer2	ds.b	PLANE*2

 end
