/* ******************************************************************** *\
 *									*
 *	Title    : BBC/DOS File I/O For Protected Mode Monitor.		*
 *	Created  : 25/10/92						*
 *	Author   : Tony Hanratty					*
 *									*
 *									*
 * Written to allow copying of files *FROM* BBC disks *TO* IBM disks.	*
 * Only one file can be 'open' at a time to make my life simpler.	*
 *									*
 * N.B. The processor is in protected mode and there is no DOS in the 	*
 *	machine so you cant call any C library functions that use DOS	*
 *	or the BIOS. So if you want to do anything ether do it yourself *
 *	or ask the monitor to do it for you.				*
 *									*
 * N.B. These functions must ONLY be call from MONBBC.ASM which does	*
 *	all the necessary interfacing between the C and assembler. To	*
 *	read BBC files or write DOS files, use the assembler routines	*
 *	in MONBBC.ASM, done call these directly.			*
 *									*
\* ******************************************************************** */


/*

(This bit is to remind me how it works...)

 BBC files are read as sectors because the files are stored contiguously
 so you just have to find the start sector and keep going till you have
 read it all. The DOS output on the other hand is more akin to very simple
 file handling due to the FAT being written for each file created. Physical
 output to the DOS disk is not sector but cluster based.

 Presume BBC filelength <= 65535 bytes
 Presume BBC load & exec addresses <= FFFF (see BBC tech info)

*/



/* Programme constants first
*/

#define		DOS_DRIVE	1		/* hard coded for now, must */
#define		BBC_DRIVE	0		/* move to config menu */

#define		BBC_SEC_TRK	10		/* BBC physical secs/track */
#define		BBC_NUM_HEADS	1		/* each side is a separate disk */

#define		BBC_SECTOR_SIZE	256

#define		MAX_BBC_FILES	31

#define 	FREE_CLUSTER	0x0000		/* FAT cluster entries */
#define 	LAST_CLUSTER	0xFFF8



/* Return error code definitions
*/

#define		CE_NO_ERROR		0		/* >>MUST<< be zero */

#define		CE_FILE_OPEN		1		/* 1 file at a time */
#define		CE_NOFILE_OPEN		2
#define		CE_MAX_FILES		3		/* too many files */
#define		CE_DOS_READ_ERROR	4
#define		CE_DOS_WRITE_ERROR	5
#define		CE_BBC_READ_ERROR	6
#define		CE_BBC_WRITE_ERROR	7
#define		CE_DOS_FAT_WRITE_ERR	8
#define		CE_DOS_ROOT_WRITE_ERR	9
#define		CE_BBC_CATALOG_ERR	10		/* Xlinked BBC files */
#define		CE_ALLOC_ERR		11		/* cant alloc mem */
#define		CE_DEALLOC_ERR		12		/* cant dealloc mem */
#define		CE_BREAK_ERR		13



/* A few handy typedefs
 */

typedef unsigned char BYTE;
typedef unsigned int  WORD;
typedef unsigned long DWORD;



/* A few handy debugging macros
 */

#define		dbgmessval(mess,aword)  { asm_pstring(mess); \
					  asm_phexword(aword); \
					  C_pcrlf(1); }

#define		dbgmess(mess)     	{ asm_pstring(mess); }

#define		dbgmessaddr(mess,addr)	{ asm_pstring(mess);\
					  asm_phexword(* ( (WORD *) addr+1));\
					  asm_pchar(':');\
					  asm_phexword(* ( (WORD *) addr));\
					  C_pcrlf(1);}




/* BBC linked sector list node structure for checking
 * for cross linked files or nonsense catalog entries.
*/

typedef struct {
	unsigned int catnum;
	unsigned int start_sector;
	unsigned int end_sector;
 } BBCSectorNode;




/* DOS Boot sector structure
*/

typedef struct  {
    BYTE jump_instruction [3];
    char oem_name [8];
    WORD bytes_per_sector;
    BYTE sectors_per_cluster;
    WORD reserved_sectors;
    BYTE no_of_FATs;
    WORD no_of_root_entries;
    WORD total_sectors;
    BYTE media_descriptor;
    WORD sectors_per_FAT;
    WORD sectors_per_track;
    WORD no_of_heads;
    WORD no_of_hidden_sectors;
    BYTE loader_routine [512 - 0x1E];
  } DOS_BOOT_SECTOR;



/* DOS Directory Entry Structure
*/

typedef struct {
  char filename [11];
  BYTE attribute;
  BYTE reserved [10];
  WORD time;
  WORD date;
  WORD first_cluster;
  DWORD filesize;
} DIRECTORY_ENTRY;




/* BBC Sector 0 part structure
*/

typedef struct {
    char BBCfilename0 [7];
    BYTE BBCdirectory;
} BBCdirentry0;


/* BBC Sector 1 part structure
*/

typedef struct {
    WORD BBCload;
    WORD BBCexec;
    WORD BBClength;
    BYTE BBChibits;
    BYTE BBCstartsector;
} BBCdirentry1;


/* Combine BBC secs 0 & 1 into following 512 byte, 2 sector structure
*/

typedef struct {
    char BBCdiskname0 [8];
    BBCdirentry0 BBCfiles0 [31];
    char BBCdiskname1 [4];
    BYTE BBCsequence;
    BYTE BBCnumfiles;
    BYTE BBCtotsecsHi_OPT;
    BYTE BBCtotsecsLo;
    BBCdirentry1 BBCfiles1 [31];
} BBC_BOOT;




/* Local Function Prototypes
*/

int alloc_DOS_boot (void);
int alloc_BBC_boot (void);
int alloc_cluster_buffer (void);
int alloc_disk_buffer (void);

int wipe_DOS_root (void);
int write_DOS_root (int);
int write_DOS_FATs (void);

int read_DOS_abs_sectors  (int, int, BYTE far *);
int write_DOS_abs_sectors (int, int, BYTE far *);

int output_DOS_sector (BYTE far *);
int output_DOS_cluster (void);
int init_DOS_disk (void);
int inti_BBC_disk (void);

int open_DOS_file (char far *, DWORD);
int copy_file_contents (unsigned int, unsigned int);
int close_DOS_file (void);

void C_pcrlf (int);
void C_pspace (int);
void C_pstring_n (char far *, int);
void C_dealloc_buffers (void);

void pBBCDiskInfo (void);
int  CheckNodeTree (int);
void FillNodeTree (int);
void SortNodeTree (int);
void pCatalog (int);
void SwapNodes (int,int);
void pNodeDetail (int);
void pNodesError (int);




/* External Assembler Function Prototypes (in the monitor file MONBBC.ASM)
*/
		       /* Dsk   C   H   S    #   buff  */
extern int read_DOS_CHS  (int, int,int,int, int, BYTE far *);
extern int write_DOS_CHS (int, int,int,int, int, BYTE far *);
extern int read_BBC_CHS  (int, int,int,int, int, BYTE far *);

extern void asm_pstring (char *);
extern void asm_pchar (char);
extern void asm_phexbyte (BYTE);
extern void asm_phexword (WORD);
extern char asm_gkey (void);




/* Global Buffers For DOS (all near pointers to far data items)
 *
 * DIRECTORY_ENTRY DOSrootdir [no_of_root_files] = {0};
 * int  clusters      [max_cluster_no] = {0};
 * DOS_BOOT_SECTOR DOSbootsector = {0};
 * BYTE twelve_bit    [max_cluster_no * 3 / 2) + 1] = {0};
 * BYTE clusterbuffer [4096] = {0};
 *
 * N.B. THESE FAR POINTERS ARE 'SELECTOR:OFFSET', NOT 'SEGMENT:OFFSET'. WE
 *	CALL THE MONITOR 16M MEMORY MANAGER ROUTINES TO ALLOCATE MEMORY WHICH
 *	RETURNS A SELECTOR INTO THE GDT. SO ANY POINTER ARITHMATIC MUST ONLY
 *	OPERATE ON THE OFFSET PORTION, NOT THE GDT SELECTOR OTHERWISE YOU'LL
 *	GENERATE A GENERAL PROTECTION FAILURE AND WARM BOOT THE MONITOR.
 *
 * All globals must be initialised so they appear in the correct data segment.
 * Unfortunately the Aztec C compiler uses non-standard segment names, so these
 * are grouped together with the main monitor segments into one unified code
 * segment and one unified data segment, namely DGROUP and PGROUP.
 *
*/

DIRECTORY_ENTRY far * DOSrootdir = (far *) 0;
int		far * clusters = (far *) 0;
DOS_BOOT_SECTOR	far * DOSbootsector = (far *) 0;
BYTE		far * twelve_bit = (far *) 0;
BYTE		far * clusterbuffer = (far *) 0;



/* Globale variables for DOS
*/

int DOS_file_open = 0;
int no_of_files = 0;
int this_cluster_no = 2;
int sector_number = 0;
int no_of_clusters = 0;
int max_cluster_no = 0;


/* Global Variables For BBC
*/

BBC_BOOT	far *BBCboot = (far *) 0;
BBCSectorNode	SectorNodes [MAX_BBC_FILES] = {0};
BYTE		BBCside = 0;


/* Global common variables/buffers for DOS & BBC
*/

BYTE	far *DiskBuffer = (far *) 0;	/* allocated by mem manager */
BYTE	show_DCHS = 0;			/* show low level disk I/O */
WORD	Selectors [20] = {0};		/* allocated memory block selectors */
int	selectors_allocated = 0;	/* # entries in selector array */



char upper (ch)					/* convert char to uppercase */
char ch;
{
  if (ch>='a' && ch<='z')
	return (ch & 0xdf);

  return (ch);
}


char GetYN()
{
char akey;

 for (akey=' ' ; akey != 'Y' && akey != 'N' ; akey=upper(asm_gkey()) );
 asm_pchar (akey );
 return ( akey );
}




/****************************************************************************\
 *
 *		Top Level Routine - Called From The Monitor
 *
\****************************************************************************/

void C_BeebCopyTop()
{
int rcode;
WORD selector;

/* Reset global selector array
 */

selectors_allocated = 0;


/* 1st allocated the memory blocks that are independent of DOS/BBC disk sizes 
*/

 if (rcode=alloc_DOS_boot())
	asm_pstring("\n\rCant allocate memory for DOS boot sector\n\r");

 else if (rcode=alloc_BBC_boot())
	asm_pstring("\n\rCant allocate memory for BBC boot sector\n\r");

 else if (rcode=alloc_disk_buffer())
	asm_pstring("\n\rCant allocate memory for disk buffer\n\r");
 else {
	asm_pstring("Static buffers allocated\n\r");
	rcode = C_BeebCopy();
	}

 asm_pstring("\n\rReturn code=");
 asm_phexword (rcode);
 C_pcrlf (1);

 C_dealloc_buffers();

}




int C_BeebCopy ()
{
BYTE akey;
int rcode;


 asm_pstring ("\n\rSelect BBC disk side 0 or 1   : ");
 for (akey=7 ; akey>1 ; akey=asm_gkey()-'0') ;
 BBCside = akey;
 asm_pchar (akey+'0');

 asm_pstring ("\n\rShow disk access info (Y/N) ? : ");
 show_DCHS = ( GetYN() == 'Y' ? 1 : 0 );

 asm_pstring ("\n\n\rPlace BBC disk in drive ");
 asm_pchar ('A'+BBC_DRIVE);
 asm_pstring (":  Press any key to continue...");
 asm_gkey();
 C_pcrlf (1); 

 if (rcode=init_BBC_disk()) {
	asm_pstring("\n\rCant read BBC catalog\n\r\007");
	return ( rcode );
	}

  if (rcode=C_copy_option()) {
	asm_pstring("\n\rCopy Failed... ");
	asm_phexword(rcode);
	C_pcrlf(1);
	}

  return ( rcode );
}





/****************************************************************************\
 *
 *		Little Farty Routines Up At The Top Here
 *
\****************************************************************************/

void C_pcrlf(n)					/* Print CR/LF 'n' Times */
int n;
{ while (n--) asm_pstring("\n\r"); }


void C_pspace(n)				/* Print 'n' spaces */
int n;
{  while (n--) asm_pchar(' '); }


void C_pstring_n (str, n)			/* Print n chars of a string */
char far *str; int n;
{ while (n--) asm_pchar(*str++); }


/* tstst
BYTE far *aptr = { (BYTE far *) 0};
*/

void memset (addr, size, fill)			/* Fill memory with a byte */
BYTE far *addr;
BYTE fill;
int size;
{ 

/* tstst
 WORD aword;
 asm_pstring("memset called with address = ");
 aword = * ( (WORD far *) &addr+1);
 asm_phexword(aword);
 asm_pchar(':');
 aword = * ( (WORD far *) &addr);
 asm_phexword(aword);
 C_pcrlf(1);
*/

if (size) while (size--) *addr++ = fill; }


void memcpy (source, dest, size)		/* copy memory */
BYTE far *source;
BYTE far *dest;
int size;
{ if (size) while (size--) *dest++ = *source++; }






/****************************************************************************\
 *
 *	Convert All Chars In A DOS Filename To Uppercase
 *
\****************************************************************************/

void upDOSfile(fp)
char *fp;
{
 int charnum;

/* DOS filenames are 12 bytes long, so count from 0 to 11
 */

 for (charnum=0 ; charnum<11 ; charnum++)
	*(fp+charnum) = upper( *(fp+charnum) );
}





/****************************************************************************\
 *
 *  Write_DOS_fats - write out the FATs to the DOS disk
 *
\****************************************************************************/

int write_DOS_FATs ()
{
int fat_no, pair_no, cluster;
int left, right;
BYTE *fp;
int rcode;
DOS_BOOT_SECTOR far *bsp = DOSbootsector;


/* Mark all remaining clusters as unused
 */

 for (cluster = this_cluster_no ; cluster <= max_cluster_no ; cluster++)
   clusters [cluster] = FREE_CLUSTER;

 twelve_bit [0] = bsp->media_descriptor;
 twelve_bit [1] = 0xFF;
 twelve_bit [2] = 0xFF;

 for (pair_no = 1; pair_no < no_of_clusters / 2; pair_no++) {
   left = clusters [pair_no*2] & 0xFFF;
   right = clusters [pair_no*2+1] & 0xFFF;
   twelve_bit [pair_no*3+0] = left;
   twelve_bit [pair_no*3+1] = (left >> 8) + ((right & 0x0F) << 4);
   twelve_bit [pair_no*3+2] = right >> 4;
   }

 for (fat_no = 0 ; fat_no < bsp->no_of_FATs ; fat_no++) {
   rcode = write_DOS_abs_sectors (1 + fat_no * bsp->sectors_per_FAT,
				bsp->sectors_per_FAT,
				twelve_bit);
   if (rcode) return (rcode);
   }

 return ( CE_NO_ERROR );

}








/****************************************************************************\
 * Write The Root Directory Out Onto The DOS Disk
 *
 * LOCAL routine
\****************************************************************************/

int write_DOS_root (files_left)
int files_left;
{
DOS_BOOT_SECTOR far *bsp = DOSbootsector;
int start_sec, num_secs;

 start_sec = 1 + bsp->no_of_FATs * bsp->sectors_per_FAT;
 num_secs  = (bsp->no_of_root_entries*sizeof(DIRECTORY_ENTRY) ) / bsp->bytes_per_sector ;

 return ( write_DOS_abs_sectors (start_sec, num_secs, (BYTE far *) DOSrootdir) );
}








int wipe_DOS_root()
{
int numsecs, startsec, sec_count, rcode;
DOS_BOOT_SECTOR far *bsp = DOSbootsector;

 memset ( DiskBuffer, 512, 0 );
 startsec = 1 + bsp->no_of_FATs * bsp->sectors_per_FAT;
 numsecs  = bsp->no_of_root_entries*sizeof(DIRECTORY_ENTRY) / bsp->bytes_per_sector;

 for (sec_count=0 ; sec_count<numsecs ; sec_count++)
	if ( rcode=write_DOS_abs_sectors (startsec+sec_count, 1, DiskBuffer) )
		break;

 return ( rcode ? rcode : CE_NO_ERROR );
}






/****************************************************************************\
 * Take a formatted DOS disk and wipe the FATs and directory ready
 * for file creation. Read in its bootsector for BPB values.
 *
 * Any non zero return value is a fault
 *
 * PUBLIC routine called in MONBBC.ASM
\****************************************************************************/

int init_DOS_disk()
{
int sector, fat, cluster, rcode;
DOS_BOOT_SECTOR far *bsp = DOSbootsector;


/* tstst */
 dbgmess("In init_DOS_disk()\n\r");


/* must reset global vars first
 */

 DOS_file_open = 0;
 no_of_files = 0;
 this_cluster_no = 2;
 sector_number = 0;


/* read in the boot sector for disk BPB
 */

 if ( read_DOS_CHS (DOS_DRIVE, 0,0,1, 1, (BYTE far *) bsp) )
	return ( CE_DOS_READ_ERROR );


/* now allocate the size dependent buffers
*/

 if (rcode = alloc_sized_buffers() )
	return ( rcode );

/* Now wipe internal buffers and arrays
 */

 memset ( (BYTE far *) clusterbuffer ,
		bsp->sectors_per_cluster * bsp->bytes_per_sector ,
		(BYTE) 0 );

 memset ( (BYTE far *) DOSrootdir ,
		bsp->no_of_root_entries * sizeof(DIRECTORY_ENTRY) ,
		(BYTE) 0 );

 for (cluster=2 ; cluster <= max_cluster_no ; cluster++)
	clusters [cluster] = 0;

/* Now physically blank the FATs and the root on the disk
 */

 if  ( write_DOS_FATs() )
	return ( CE_DOS_FAT_WRITE_ERR );

 if ( wipe_DOS_root() )
	return ( CE_DOS_ROOT_WRITE_ERR );

 return ( CE_NO_ERROR );
}






/****************************************************************************\
 * Creates an entry in the root directory for a new file. The directory
 * and FATs are written when the file is closed. The filename is passed
 * in BBC format, 7 bytes long, and the 8th byte is the BBC catalog
 * directory. In DOS we use the directory as the file extension to advoid
 * duplicate file names. No physical write occurs to disk in this routine.
 *
 * LOCAL
\****************************************************************************/

int open_DOS_file (fname, flen)
char far *fname;
DWORD flen;
{
int namelen;
char far *nameptr;

 if (DOS_file_open)
	return ( CE_FILE_OPEN );

 if (no_of_files == DOSbootsector->no_of_root_entries-1)
	return ( CE_MAX_FILES );



/* copy 7 byte BBC file name into DOS directory, pad with spaces to 11 chars
 * and make uppercase because BBC filenames can be have lowercase chars.
*/

 nameptr = DOSrootdir [no_of_files].filename;	/* point to DOS dir entry */
 memset (nameptr, 11, 32);			/* fill name with spaces  */
 memcpy (fname, nameptr, 7);			/* copy in BBC file name  */
 nameptr[8] = upper((char)(fname[7] & 0x7f));	/* extension=BBC directory */
 upDOSfile (nameptr);				/* make sure uppercase */


/* fill in rest of DOS dir entry now
 */

 DOSrootdir [no_of_files].filesize = flen;
 DOSrootdir [no_of_files].time = 0;
 DOSrootdir [no_of_files].date = 0;
 DOSrootdir [no_of_files].first_cluster = this_cluster_no;
 DOSrootdir [no_of_files].attribute = 0x20;


/* zero the cluster buffer
 */

 memset ( (BYTE far *) clusterbuffer ,
	 DOSbootsector->sectors_per_cluster*DOSbootsector->bytes_per_sector,
	 (BYTE) 0 );


/* init cluster sector counter to 0 & flag file open
 */

 sector_number=0;
 DOS_file_open++;

 return ( CE_NO_ERROR );
}






/****************************************************************************\
 * Append sector to cluster buffer. Physical write if a complete DOS cluster.
 *
 * LOCAL routine
\****************************************************************************/

int output_DOS_sector (dataptr)
BYTE far *dataptr;
{
BYTE far *dp;
int bcnt, rc;


/* copy data into clusterbuffer
 */

 dp = clusterbuffer + (DOSbootsector->bytes_per_sector*sector_number);
 for (bcnt = 0 ; bcnt < DOSbootsector->bytes_per_sector ; bcnt++ )
	*dp++ = *dataptr++;


/* If we have a full cluster, write it to the disk. The FAT is updated
 * when the file is closed.
 */

 if (++sector_number == DOSbootsector->sectors_per_cluster) {
	sector_number = 0;
	return (output_DOS_cluster());
	}
		
 return ( CE_NO_ERROR );
}






/****************************************************************************\
 * Output cluster buffer to next free DOS cluster. ie Append to DOS file.
 *
 * LOCAL routine
\****************************************************************************/

int output_DOS_cluster()
{
int spc = DOSbootsector->sectors_per_cluster;
int rcode, abs_sec, data_sector_start;
DOS_BOOT_SECTOR far *dbs = DOSbootsector;


/*  make sure a file is open
*/

if ( DOS_file_open == 0 )
	return ( CE_NOFILE_OPEN );


/* calculate abs logical sector number of this cluster
*/

 data_sector_start = dbs->no_of_root_entries * sizeof(DIRECTORY_ENTRY) / dbs->bytes_per_sector;
 data_sector_start += (dbs->sectors_per_FAT * dbs->no_of_FATs + 1);

 abs_sec = (this_cluster_no-2)*spc + data_sector_start;


/* flag this cluster as used and link to next
*/

 clusters [this_cluster_no] = this_cluster_no+1;
 this_cluster_no++;

/* ask for physical write to disk
*/

 rcode = write_DOS_abs_sectors (abs_sec, spc, clusterbuffer);
 return ( rcode );

}







/****************************************************************************\
 * Call monitor for physical write to DOS disk at absolute sector number.
 * Passed start sector number, # sectors to write, buffer address.
 *
 * LOCAL routine
\****************************************************************************/

int write_DOS_abs_sectors (abs_sec, numsecs, buffer)
int abs_sec, numsecs;
BYTE far *buffer;
{
int cyl, head, sec;
int spt = DOSbootsector->sectors_per_track,
    noh = DOSbootsector->no_of_heads;


/* calculate cylinder, head, sector disk address
*/

 sec  = (abs_sec % spt) + 1;
 head = (abs_sec / spt) % noh;
 cyl  =  abs_sec / (noh*spt);


/* call monitor for physical write
*/

 if ( write_DOS_CHS (DOS_DRIVE, cyl,head,sec, numsecs, buffer) )
	return ( CE_DOS_WRITE_ERROR );
 else
	return ( CE_NO_ERROR );
}









/****************************************************************************
 * Read abs BBC logical sector number into buffer.
 * N.B. Head number is patched in MONBBC.ASM !!
 *
 * LOCAL routine
 ****************************************************************************/

int read_BBC_abs_sectors (abs_sec, numsecs, buffer)
int abs_sec, numsecs;
BYTE far *buffer;
{
int cyl, head, sec;


/* calculate cylinder, head, sector
*/

 sec  = (abs_sec % BBC_SEC_TRK);
 head = (abs_sec / BBC_SEC_TRK) % BBC_NUM_HEADS;
 cyl  =  abs_sec / (BBC_SEC_TRK * BBC_NUM_HEADS);


/* ask monitor to do physical read
*/

 if ( read_BBC_CHS (BBC_DRIVE, cyl,head,sec, numsecs, buffer) )
	return ( CE_BBC_READ_ERROR );
 else
	return ( CE_NO_ERROR );
}







/****************************************************************************
 * Close currently open DOS file. Flush cluster buffer to disk if it
 * contains unwritten data.
 *
 * LOCAL routine
 ****************************************************************************/

int close_DOS_file()
{
int rcode;

 if (DOS_file_open == 0)
	return ( CE_NOFILE_OPEN );

/* tstst lots of these in this routine */
 dbgmess("\n\rClosing DOS file\n\r");

/* flush out anything in the cluster buffer
 */

 if (sector_number) {
	asm_pstring("\n\rFlushing First\n\r");
	if ( rcode=output_DOS_cluster() )
		return ( rcode );
	}
 clusters [this_cluster_no-1] = LAST_CLUSTER;

 DOS_file_open--;
 no_of_files++;

 dbgmess("Writing FATs\n\r");	/* tstst */
 if ( rcode=write_DOS_FATs() )
	return ( rcode );
 
 dbgmess("Writing Root\n\r");	/* tstst */
 if ( rcode=write_DOS_root(no_of_files) )
	return ( rcode );


 dbgmess("File Closed\n\r");	/* tstst */

return ( CE_NO_ERROR );
}







/****************************************************************************
 * Read in directory sectors 0 & 1 to the BBC 'boot' structure.
 *
 * PUBLIC routine - called from MONBBC.ASM
 ****************************************************************************/

int init_BBC_disk()
{
int filenum, charnum;
char *nameptr;

/* tstst */
 dbgmess("In init_BBC_disk\n\r");

/* zero the memory 1st */

 memset ( (BYTE far *) BBCboot, sizeof(BBC_BOOT), (BYTE) 0 );

 if ( read_BBC_CHS (BBC_DRIVE, 0,0,0, 2, (BYTE far *) BBCboot) )
	return ( CE_BBC_READ_ERROR );
 else
	return ( CE_NO_ERROR );
}






/****************************************************************************
 * Step through all files in the BBC disk catalog and copy them to the
 * DOS disk.
 *
 * PUBLIC routine - called from MONBBC.ASM
 ****************************************************************************/

int C_copy_option()
{
unsigned int startsec, filelen;
char far *filename;
char akey;
BYTE directory;
unsigned int totfiles, filenum, rcode;
BBCdirentry1 far *dir1;
BBCdirentry0 far *dir0;


 totfiles  = BBCboot->BBCnumfiles >> 3;

 pBBCDiskInfo();
 pCatalog (totfiles);

 if (rcode=CheckNodeTree (totfiles))
	return ( rcode );
 else
	asm_pstring ("File allocation chain OK\n\r");



 asm_pstring ("Display allocation info (Y/N) ? ");

 if ( GetYN() == 'Y') {
	C_pcrlf (1);
	for (filenum=0 ; filenum<totfiles ; filenum++) {
		C_pcrlf ( ((filenum % 2)==0) ? 1 : 0);
		asm_pstring ("   ");
		pNodeDetail (filenum);
		}
	C_pcrlf (1);
	}



 asm_pstring ("\n\r\rCopy files (Y/N) ? ");
 akey=GetYN();
 C_pcrlf (2);
 if (akey != 'Y')
	return ( CE_NO_ERROR );

 if (rcode=init_DOS_disk()) {
	asm_pstring("Cant read or write DOS disk track 0\n\r\007");
	return (rcode);
	}


 for (filenum=0 ; filenum<totfiles ; filenum++) {
	 dir0 = &BBCboot->BBCfiles0 [ SectorNodes[filenum].catnum ];
	 dir1 = &BBCboot->BBCfiles1 [ SectorNodes[filenum].catnum ];

	 filename = dir0->BBCfilename0;
	 filelen  = dir1->BBClength;
	 startsec = SectorNodes[filenum].start_sector;

	/* Print File details: directory, name, length, start sector */

	 asm_pchar (dir0->BBCdirectory & 0x7f);
	 asm_pchar ('.');
	 C_pstring_n (filename, 7);
	 C_pspace (5);
	 asm_pdecimal (filelen);
	 C_pspace (2);
	 asm_pdecimal (startsec);
	 C_pcrlf (1);


	/* Now copy the file */

	 if ( rcode=open_DOS_file (filename, filelen) )
		return ( rcode );

	 if ( rcode=copy_file_contents (filelen, startsec) )
		return ( rcode );

	 if ( rcode=close_DOS_file() )
		return ( rcode );

	}


 return ( CE_NO_ERROR );
}










/****************************************************************************
 * Copy Opened BBC Files Contents To DOS Disk.
 * Call With File Length In Bytes and Start Sector Number.
 *
 * LOCAL
 ****************************************************************************/

int copy_file_contents (filelen, startsec)
unsigned int startsec, filelen;
{
 int rcode, numsecs;
 char akey;
 int dumpcount;


/* Before each DOS write must read in 2 BBC sectors to make 1 DOS
 * sector.
 */

 numsecs = (filelen/BBC_SECTOR_SIZE) + ( (filelen & 0xFF) ? 1 : 0);

 if (numsecs & 1) numsecs++;			/* up to even # secs */


 while (numsecs) {

	 if ( rcode=read_BBC_abs_sectors (startsec, 2, DiskBuffer) )
		return ( rcode );

	 if ( rcode=output_DOS_sector (DiskBuffer) )
		return ( rcode );

	startsec += 2;
	numsecs -= 2;

	}
 return ( CE_NO_ERROR );
}







void pBBCDiskInfo ()
{
int totsecs, totfiles;
BYTE bootopt, sequence;

 totsecs  = BBCboot->BBCtotsecsLo + ( (BBCboot->BBCtotsecsHi_OPT & 3) << 8);
 bootopt  = (BBCboot->BBCtotsecsHi_OPT & 0x30) >> 4;
 sequence = BBCboot->BBCsequence;
 totfiles = (BBCboot->BBCnumfiles >> 3);

 asm_pstring ("\n\rDisk title        : ");
 C_pstring_n (BBCboot->BBCdiskname0, 8);
 C_pstring_n (BBCboot->BBCdiskname1, 4);
 asm_pstring ("\n\rFiles on disk (d) : ");
 asm_pdecimal (totfiles);
 asm_pstring ("\n\rTotal sectors (d) : ");
 asm_pdecimal (totsecs);
 asm_pstring ("\n\rSequence Num  (h) : ");
 asm_phexbyte (sequence);
 asm_pstring ("\n\r!BOOT option  (h) : ");
 asm_phexbyte (bootopt);
 C_pcrlf (2);
}










void pCatalog(numfiles)
int numfiles;
{
int fcount;
BBCdirentry0 far *dir0;

 for (fcount=0 ; fcount < numfiles ; fcount++ ) {
	dir0 = &BBCboot->BBCfiles0 [fcount];
	if ((fcount % 4)==0)
		asm_pstring("\n\r      ");
	asm_pchar ((char) (dir0->BBCdirectory & 0x7f));
	asm_pchar ( (char) '.');
	C_pstring_n (dir0->BBCfilename0, 7);
	asm_pstring("        ");
	}

 C_pcrlf(2);
}







/****************************************************************************\
 *
 *			All Node Routines After Here
 *
\****************************************************************************/

void SwapNodes(a,b)
int a,b;
{
BBCSectorNode tempnode;

tempnode=SectorNodes[a];
SectorNodes[a]=SectorNodes[b];
SectorNodes[b]=tempnode;

}






int CheckNodeTree (numfiles)
int numfiles;
{
int fcount, rcode;
BBCSectorNode *aNodePtr;

FillNodeTree (numfiles);		/* fill node tree from the catalog */
SortNodeTree (numfiles);		/* Now sort into start_sec order */


/* Now make sure theres no sector overlap
*/

 rcode=CE_NO_ERROR;

 for (fcount=0 ; fcount<numfiles-1 ; fcount++) {
	aNodePtr = &SectorNodes[fcount];
	if (aNodePtr[0].end_sector >= aNodePtr[1].start_sector) {
		pNodesError (fcount);
		rcode = CE_BBC_CATALOG_ERR;
		}
	}

 return (rcode);
}








void pNodeDetail(n)
int n;
{
BBCdirentry0 far *dir0;
BBCdirentry1 far *dir1;

  dir0 = &BBCboot->BBCfiles0[SectorNodes[n].catnum];
  dir1 = &BBCboot->BBCfiles1[SectorNodes[n].catnum];


   asm_pchar (dir0->BBCdirectory & 0x7f);
   asm_pchar ('.');
   C_pstring_n (dir0->BBCfilename0, 7);
   asm_pdecimal (SectorNodes[n].start_sector);
   asm_pdecimal (SectorNodes[n].end_sector);
   C_pspace (1);
   asm_pdecimal (dir1->BBClength);
   C_pspace (1);
   asm_phexword (dir1->BBCload);
   C_pspace (1);
   asm_phexword (dir1->BBCexec);
}



void pNodesError (n)
int n;
{
 asm_pstring ("Files Crosslinked...");
 asm_pstring ("      ");
 pNodeDetail (n);
 asm_pstring ("            ");
 pNodeDetail (n+1);
 C_pcrlf (1);
}





void FillNodeTree (numfiles)
int numfiles;
{
BBCdirentry1 far *dir1;
unsigned int fcount, startsec, numsecs, filelen;
BYTE hibits;

 for (fcount=0 ; fcount<numfiles ; fcount++) {
	dir1 = &BBCboot->BBCfiles1 [fcount];

	hibits   = dir1->BBChibits;
	startsec = dir1->BBCstartsector + ((hibits & 0x3) << 8);
	numsecs  = (filelen+BBC_SECTOR_SIZE-1)/BBC_SECTOR_SIZE;

	SectorNodes [fcount].catnum       = fcount;
	SectorNodes [fcount].start_sector = startsec;
	SectorNodes [fcount].end_sector   = startsec+numsecs-1;

	}
}





void SortNodeTree (numfiles)
int numfiles;
{
int sorted, fcount;

do {
 sorted=1;
 for (fcount=0 ; fcount<numfiles-1 ; fcount++) {
	if (SectorNodes[fcount].start_sector > SectorNodes[fcount+1].start_sector) {
		SwapNodes(fcount, fcount+1);
		sorted=0;
		}
	}
 } while (!sorted);

}





/* Allocate block of memory, length in bytes
 * the external assembler reoutine returns 0 if allocation failed
 * else it returns a selector to the allocated memory block.
 *
 * Processor must be in protected mode.
 */

WORD C_alloc_mem (len)
unsigned int len;
{
WORD selector;

 if (selector = asm_alloc_mem (len) ) {
 	Selectors [ selectors_allocated++ ] = selector;
	return ( selector );
	}
 else
	return ( (WORD) 0);
}






/* Deallocate a memory block. Returns passed selector if OK, 0=fail
 *
 * Must be in protected mode.
 */

WORD C_dealloc_mem (selector)
WORD selector;
{
 return ( asm_dealloc_mem (selector) );
}




void C_dealloc_buffers()
{
int SelectorNumber;
WORD selector;

 for (SelectorNumber=0 ; SelectorNumber<selectors_allocated ; SelectorNumber++) {
	selector = Selectors [ SelectorNumber ];
	if (C_dealloc_mem ( selector ) != selector ) {
		asm_pstring("Deallocate failed on selector ");
		asm_phexword ( selector );
		C_pcrlf(1);
		}
	}

 selectors_allocated = 0;
}





/****************************************************************************\
 *
 *	Call The Monitor Memory Manager To Allocate Space For Our Arrays
 *
 * These calls to the memory manager all work the same: if the call fails,
 * return the appropriate error code, else set the offset part of the far
 * pointer to zero, and patch the returned selector to the memory block
 * into what would be the segment part of the pointer in real mode.
\****************************************************************************/

int alloc_sized_buffers()
{
WORD size, selector;
DOS_BOOT_SECTOR far *bsp = DOSbootsector;


/* tstst
 */
 dbgmess("In alloc_sized_buffers()\n\r");

 no_of_clusters  = bsp->total_sectors - (bsp->no_of_FATs * bsp->sectors_per_FAT);
 no_of_clusters -= (bsp->no_of_root_entries*sizeof(DIRECTORY_ENTRY) / bsp->bytes_per_sector);
 no_of_clusters -= bsp->reserved_sectors;
 no_of_clusters /= bsp->sectors_per_cluster;

 max_cluster_no = no_of_clusters + 1;

/* tstst
 */
 dbgmessval ("no_of_clusters = ",no_of_clusters);


/* space for DOS root directory 1st
 */

size = sizeof(DIRECTORY_ENTRY) * (bsp->no_of_root_entries);
if ( (selector=C_alloc_mem (size))==0)
	return ( CE_ALLOC_ERR );
else {
	* (int *) &DOSrootdir = 0;			/* zero ptr offset */
	* ((WORD *) &DOSrootdir+1) = selector;		/* set ptr selector */
	}
/* tstst
 */
  dbgmessval("DOS root dir selector = ",selector);



/* our local cluster chain
 */

size = (no_of_clusters+1)*sizeof(int);			/* array based on 0 */
if ( selector=C_alloc_mem (size) ) {
	* (int *) &clusters = 0;
	* ((WORD *) &clusters+1) = selector;
	}
else
	return ( CE_ALLOC_ERR );

/* tstst
 */
 dbgmessval("clusters array selector = ",selector);




/* space to hold 1 DOS clusters worth of disk data
 */

 size = bsp->bytes_per_sector * bsp->sectors_per_cluster;
 if ( selector=C_alloc_mem (size) ) {
	* (int *) &clusterbuffer = 0;
	* ((WORD *) &clusterbuffer+1) = selector;
	}
 else
	return ( CE_ALLOC_ERR );
 /* tstst
 */
  dbgmessval("cluster buffer selector = ",selector);
  dbgmessval("cluster buffer size = ",size);





/* space to construct image of DOS 12 bit FAT
 */

size = ((no_of_clusters * 3) / 2) + 1;
if ( (selector=C_alloc_mem (size))==0)
	return ( CE_ALLOC_ERR );
else {
	* (int *) &twelve_bit = 0;
	* ((WORD *) &twelve_bit+1) = selector;
	}

/* tstst
 */
 dbgmessval("FAT image selector = ",selector);


return ( CE_NO_ERROR );

}










/* allocate space to hold DOS's boot sector */

int alloc_DOS_boot()
{
 WORD selector,size;

size = sizeof(DOS_BOOT_SECTOR);
if ( (selector=C_alloc_mem (size))==0)
	return ( CE_ALLOC_ERR );
else {
	* (int *) &DOSbootsector = 0;
	* ((WORD *) &DOSbootsector+1) = selector;
/* tstst
 */
  dbgmessval("DOS boot sector selector = ",selector);
	return ( CE_NO_ERROR );
	}
}




int alloc_BBC_boot()
{
 WORD selector;

/* space for 2 sectors of BBC catalog */

if ( (selector=C_alloc_mem (sizeof(BBC_BOOT)) )==0)
	return ( CE_ALLOC_ERR );
else {
	* (int *) &BBCboot = 0;
	* ((WORD *) &BBCboot+1) = selector;
/* tstst
 */
  dbgmessval("BBC boot sectors selector = ",selector);
	return ( CE_NO_ERROR );
	}
}







int alloc_disk_buffer()
{
WORD selector;

/* general disk sector buffer */

if ( (selector=C_alloc_mem (512))==0 )
	return ( CE_ALLOC_ERR );
else {
	* (int *) &DiskBuffer = 0;
	* ((WORD *) &DiskBuffer+1) = selector;
/* tstst
 */
  dbgmessval("DiskBuffer ram selector = ",selector);
	return ( 0 );
	}
}


