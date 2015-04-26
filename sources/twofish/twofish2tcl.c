/*
 * twofish2tcl.c
 *
 * Twofish encryption as a Tcl extension for Password Gorilla
 * Original code: opt2.c from http://www.schneier.com/code/twofish-cpy.zip
 * cbc mode added
 *
 * Version 0.1 alpha
 * Author: Zbigniew Diaczyszn
 * Last modified: 2013/05/13
 * gcc 4.2.5
 *
 * gcc -Wall -shared -fPIC -I ~/Programme/Active-Tcl-8.5/include/ -o twofish.so twofish2tcl.c
 *   -DUSE_TCL_STUBS
 *
 * gcc -Wall -shared -fPIC -DUSE_TCL_STUBS -I
 * ~/Programme/Active-Tcl-8.5/include/ -o twofish.so twofish2tcl.c \
 * -L ~/Programme/Active-Tcl-8.5/lib/ -ltclstub8.5
 *
 * Drew Csillag's recommended flags are: -O3 -fomit-frame-pointer
 *
 * License for the Twofish source code:
 *
 * The main twofish page at http://www.schneier.com/twofish.html says
 * this:
 *
 * Twofish is unpatented, and the source code is uncopyrighted and
 * license-free; it is free for all uses.
 *
 * So the code in this program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
*/

// GF() : Galois field is a field that contains a finite number of elements.

#include <string.h>
#include <tcl.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <alloca.h>
#include "tables.h"

#define u32 uint32_t
#define BYTE uint8_t
#define RS_MOD 0x14D
#define RHO 0x01010101L


/***********************************************************************
 *   Definitions and functions for the Tcl wrapper
 **********************************************************************/

struct TwofishContext {
  uint32_t mode;
  uint8_t iv[16];
  uint32_t key32[40];
  uint32_t subkeys[4][256];
} ;

typedef struct TwofishContext TWOFISH_CTX;

static Tcl_HashTable engines;

#define CBC 1
#define ECB 0

/***********************************************************************
 *   Drew Csillag's Twofish implementation in opt2.c
 **********************************************************************/

/*
   gcc is smart enough to convert these to roll instructions.  If you want
   to see for yourself, either do gcc -O3 -S, or change the |'s to +'s and
   see how slow things get (you lose about 30-50 clocks) :).
*/
#define ROL(x,n) (((x) << ((n) & 0x1F)) | ((x) >> (32-((n) & 0x1F))))
#define ROR(x,n) (((x) >> ((n) & 0x1F)) | ((x) << (32-((n) & 0x1F))))

#if BIG_ENDIAN == 1
#define BSWAP(x) (((ROR(x,8) & 0xFF00FF00) | (ROL(x,8) & 0x00FF00FF)))
#else
#define BSWAP(x) (x)
#endif

#define _b(x, N) (((x) >> (N*8)) & 0xFF)

/* just casting to byte (instead of masking with 0xFF saves *tons* of clocks
   (around 50) */
#define b0(x) ((BYTE)(x))
/* this saved 10 clocks */
#define b1(x) ((BYTE)((x) >> 8))
/* use byte cast here saves around 10 clocks */
#define b2(x) (BYTE)((x) >> 16)
/* don't need to mask since all bits are in lower 8 - byte cast here saves
   nothing, but hey, what the hell, it doesn't hurt any */
#define b3(x) (BYTE)((x) >> 24)

#define BYTEARRAY_TO_U32(r) ((r[0] << 24) ^ (r[1] << 16) ^ (r[2] << 8) ^ r[3])
#define BYTES_TO_U32(r0, r1, r2, r3) ((r0 << 24) ^ (r1 << 16) ^ (r2 << 8) ^ r3)

void printSubkeys(u32 K[40])
{
    int i;
    printf("round subkeys\n");
    for (i=0;i<40;i+=2)
  printf("%08X %08X\n", K[i], K[i+1]);
}

/*
   multiply two polynomials represented as u32's, actually called with BYTES,
   but since I'm not really going to too much work to optimize key setup (since
   raw encryption speed is what I'm after), big deal.
*/
u32 polyMult(u32 a, u32 b)
{
    u32 t=0;
    while (a)
    {
  /*printf("A=%X  B=%X  T=%X\n", a, b, t);*/
  if (a&1) t^=b;
  b <<= 1;
  a >>= 1;
    }
    return t;
}

/* take the polynomial t and return the t % modulus in GF(256) */
u32 gfMod(u32 t, u32 modulus)
{
    int i;
    u32 tt;

    modulus <<= 7;
    for (i = 0; i < 8; i++)
    {
  tt = t ^ modulus;
  if (tt < t) t = tt;
  modulus >>= 1;
    }
    return t;
}

/*multiply a and b and return the modulus */
#define gfMult(a, b, modulus) gfMod(polyMult(a, b), modulus)

/* return a u32 containing the result of multiplying the RS Code matrix
   by the sd matrix
*/
u32 RSMatrixMultiply(BYTE sd[8])
{
    int j, k;
    BYTE t;
    BYTE result[4];

    for (j = 0; j < 4; j++)
    {
  t = 0;
  for (k = 0; k < 8; k++)
  {
      /*printf("t=%X  %X\n", t, gfMult(RS[j][k], sd[k], RS_MOD));*/
      t ^= gfMult(RS[j][k], sd[k], RS_MOD);
  }
  result[3-j] = t;
    }
    return BYTEARRAY_TO_U32(result);
}

/* the Zero-keyed h function (used by the key setup routine) */
u32 h(u32 X, u32 L[4], int k)
{
    BYTE y0, y1, y2, y3;
    BYTE z0, z1, z2, z3;
    y0 = b0(X);
    y1 = b1(X);
    y2 = b2(X);
    y3 = b3(X);

    switch(k)
    {
  case 4:
      y0 = Q1[y0] ^ b0(L[3]);
      y1 = Q0[y1] ^ b1(L[3]);
      y2 = Q0[y2] ^ b2(L[3]);
      y3 = Q1[y3] ^ b3(L[3]);
  case 3:
      y0 = Q1[y0] ^ b0(L[2]);
      y1 = Q1[y1] ^ b1(L[2]);
      y2 = Q0[y2] ^ b2(L[2]);
      y3 = Q0[y3] ^ b3(L[2]);
  case 2:
      y0 = Q1[  Q0 [ Q0[y0] ^ b0(L[1]) ] ^ b0(L[0]) ];
      y1 = Q0[  Q0 [ Q1[y1] ^ b1(L[1]) ] ^ b1(L[0]) ];
      y2 = Q1[  Q1 [ Q0[y2] ^ b2(L[1]) ] ^ b2(L[0]) ];
      y3 = Q0[  Q1 [ Q1[y3] ^ b3(L[1]) ] ^ b3(L[0]) ];
    }

    /* inline the MDS matrix multiply */
    z0 = multEF[y0] ^ y1 ^         multEF[y2] ^ mult5B[y3];
    z1 = multEF[y0] ^ mult5B[y1] ^ y2 ^         multEF[y3];
    z2 = mult5B[y0] ^ multEF[y1] ^ multEF[y2] ^ y3;
    z3 = y0 ^         multEF[y1] ^ mult5B[y2] ^ mult5B[y3];

    return BYTES_TO_U32(z0, z1, z2, z3);
}

/* given the Sbox keys, create the fully keyed QF */
void fullKey(u32 L[4], int k, u32 QF[4][256])
{
    BYTE y0, y1, y2, y3;

    int i;

    /* for all input values to the Q permutations */
    for (i=0; i<256; i++)
    {
  /* run the Q permutations */
  y0 = i; y1=i; y2=i; y3=i;
  switch(k)
      {
          case 4:
        y0 = Q1[y0] ^ b0(L[3]);
        y1 = Q0[y1] ^ b1(L[3]);
        y2 = Q0[y2] ^ b2(L[3]);
        y3 = Q1[y3] ^ b3(L[3]);
          case 3:
        y0 = Q1[y0] ^ b0(L[2]);
        y1 = Q1[y1] ^ b1(L[2]);
        y2 = Q0[y2] ^ b2(L[2]);
        y3 = Q0[y3] ^ b3(L[2]);
          case 2:
        y0 = Q1[  Q0 [ Q0[y0] ^ b0(L[1]) ] ^ b0(L[0]) ];
        y1 = Q0[  Q0 [ Q1[y1] ^ b1(L[1]) ] ^ b1(L[0]) ];
        y2 = Q1[  Q1 [ Q0[y2] ^ b2(L[1]) ] ^ b2(L[0]) ];
        y3 = Q0[  Q1 [ Q1[y3] ^ b3(L[1]) ] ^ b3(L[0]) ];
      }

  /* now do the partial MDS matrix multiplies */
  QF[0][i] = ((multEF[y0] << 24)
        | (multEF[y0] << 16)
        | (mult5B[y0] << 8)
        | y0);
  QF[1][i] = ((y1 << 24)
        | (mult5B[y1] << 16)
        | (multEF[y1] << 8)
        | multEF[y1]);
  QF[2][i] = ((multEF[y2] << 24)
        | (y2 << 16)
        | (multEF[y2] << 8)
        | mult5B[y2]);
  QF[3][i] = ((mult5B[y3] << 24)
        | (multEF[y3] << 16)
        | (y3 << 8)
        | mult5B[y3]);
    }
}

void printRound(int round, u32 R0, u32 R1, u32 R2, u32 R3, u32 K1, u32 K2)
{
    printf("round[%d] ['0x%08XL', '0x%08XL', '0x%08XL', '0x%08XL']\n",
     round, R0, R1, R2, R3);

}

/* fully keyed h (aka g) function */
#define fkh(X) (S[0][b0(X)]^S[1][b1(X)]^S[2][b2(X)]^S[3][b3(X)])

/* one encryption round */
#define ENC_ROUND(R0, R1, R2, R3, round) \
    T0 = fkh(R0); \
    T1 = fkh(ROL(R1, 8)); \
    R2 = ROR(R2 ^ (T1 + T0 + K[2*round+8]), 1); \
    R3 = ROL(R3, 1) ^ (2*T1 + T0 + K[2*round+9]);

#define X3 BSWAP(((u32*)PT)[3])
#define X2 BSWAP(((u32*)PT)[2])
#define X1 BSWAP(((u32*)PT)[1])
#define X0 BSWAP(((u32*)PT)[0])

inline void encrypt(uint32_t K[40], uint32_t S[4][256], BYTE PT[16], int cbc, BYTE IV[16])
// inline void encrypt(u32 K[40], u32 S[4][256], BYTE PT[16], BYTE IV[16])
{
    u32 R0, R1, R2, R3;
    u32 T0, T1;

    if (cbc) {
      /* XORing PT with IV */
      BSWAP(((u32*)PT)[3]) ^= BSWAP(((u32*)IV)[3]);
      BSWAP(((u32*)PT)[2]) ^= BSWAP(((u32*)IV)[2]);
      BSWAP(((u32*)PT)[1]) ^= BSWAP(((u32*)IV)[1]);
      BSWAP(((u32*)PT)[0]) ^= BSWAP(((u32*)IV)[0]);
    }

    /* load/byteswap/whiten input */
    R3 = K[3] ^ BSWAP(((u32*)PT)[3]);
    R2 = K[2] ^ BSWAP(((u32*)PT)[2]);
    R1 = K[1] ^ BSWAP(((u32*)PT)[1]);
    R0 = K[0] ^ BSWAP(((u32*)PT)[0]);

    ENC_ROUND(R0, R1, R2, R3, 0);
    ENC_ROUND(R2, R3, R0, R1, 1);
    ENC_ROUND(R0, R1, R2, R3, 2);
    ENC_ROUND(R2, R3, R0, R1, 3);
    ENC_ROUND(R0, R1, R2, R3, 4);
    ENC_ROUND(R2, R3, R0, R1, 5);
    ENC_ROUND(R0, R1, R2, R3, 6);
    ENC_ROUND(R2, R3, R0, R1, 7);
    ENC_ROUND(R0, R1, R2, R3, 8);
    ENC_ROUND(R2, R3, R0, R1, 9);
    ENC_ROUND(R0, R1, R2, R3, 10);
    ENC_ROUND(R2, R3, R0, R1, 11);
    ENC_ROUND(R0, R1, R2, R3, 12);
    ENC_ROUND(R2, R3, R0, R1, 13);
    ENC_ROUND(R0, R1, R2, R3, 14);
    ENC_ROUND(R2, R3, R0, R1, 15);

    /* load/byteswap/whiten output */
    ((u32*)PT)[3] = BSWAP(R1 ^ K[7]);
    ((u32*)PT)[2] = BSWAP(R0 ^ K[6]);
    ((u32*)PT)[1] = BSWAP(R3 ^ K[5]);
    ((u32*)PT)[0] = BSWAP(R2 ^ K[4]);
}

/* one decryption round */
#define DEC_ROUND(R0, R1, R2, R3, round) \
    T0 = fkh(R0); \
    T1 = fkh(ROL(R1, 8)); \
    R2 = ROL(R2, 1) ^ (T0 + T1 + K[2*round+8]); \
    R3 = ROR(R3 ^ (T0 + 2*T1 + K[2*round+9]), 1);

inline void decrypt(u32 K[40], u32 S[4][256], BYTE PT[16], int cbc, BYTE IV[16])
{
    u32 T0, T1;
    u32 R0, R1, R2, R3;

    /* load/byteswap/whiten input */
    R3 = K[7] ^ BSWAP(((u32*)PT)[3]);
    R2 = K[6] ^ BSWAP(((u32*)PT)[2]);
    R1 = K[5] ^ BSWAP(((u32*)PT)[1]);
    R0 = K[4] ^ BSWAP(((u32*)PT)[0]);

    DEC_ROUND(R0, R1, R2, R3, 15);
    DEC_ROUND(R2, R3, R0, R1, 14);
    DEC_ROUND(R0, R1, R2, R3, 13);
    DEC_ROUND(R2, R3, R0, R1, 12);
    DEC_ROUND(R0, R1, R2, R3, 11);
    DEC_ROUND(R2, R3, R0, R1, 10);
    DEC_ROUND(R0, R1, R2, R3, 9);
    DEC_ROUND(R2, R3, R0, R1, 8);
    DEC_ROUND(R0, R1, R2, R3, 7);
    DEC_ROUND(R2, R3, R0, R1, 6);
    DEC_ROUND(R0, R1, R2, R3, 5);
    DEC_ROUND(R2, R3, R0, R1, 4);
    DEC_ROUND(R0, R1, R2, R3, 3);
    DEC_ROUND(R2, R3, R0, R1, 2);
    DEC_ROUND(R0, R1, R2, R3, 1);
    DEC_ROUND(R2, R3, R0, R1, 0);

    /* load/byteswap/whiten output */
    ((u32*)PT)[3] = BSWAP(R1 ^ K[3]);
    ((u32*)PT)[2] = BSWAP(R0 ^ K[2]);
    ((u32*)PT)[1] = BSWAP(R3 ^ K[1]);
    ((u32*)PT)[0] = BSWAP(R2 ^ K[0]);

    if (cbc) {
      /* XORing PT with IV */
      BSWAP(((u32*)PT)[3]) ^= BSWAP(((u32*)IV)[3]);
      BSWAP(((u32*)PT)[2]) ^= BSWAP(((u32*)IV)[2]);
      BSWAP(((u32*)PT)[1]) ^= BSWAP(((u32*)IV)[1]);
      BSWAP(((u32*)PT)[0]) ^= BSWAP(((u32*)IV)[0]);
    }
}

/* the key schedule routine has to provide 40 words of expanded keys
 * and the 4 key-dependent subkey S-boxes used in the g function. */

void keySched(BYTE M[], int N, u32 **S, u32 K[40], int *k)
// N - key length (128,192,256), here: 128
// M[]  - the 32 byte key
{
    u32 Mo[4], Me[4];
    int i, j;
    BYTE vector[8];
    u32 A, B;

    *k = (N + 63) / 64;   // here: 2
    *S = (u32*)malloc(sizeof(u32) * (*k));

    for (i = 0; i < *k; i++)
    {
  Me[i] = BSWAP(((u32*)M)[2*i]);    // Me = (M0,M2) first vector
  Mo[i] = BSWAP(((u32*)M)[2*i+1]);  // Mo = (M1,M3) second vector
    }

    for (i = 0; i < *k; i++)
    {
  // building third vector
  for (j = 0; j < 4; j++) vector[j] = _b(Me[i], j);
  for (j = 0; j < 4; j++) vector[j+4] = _b(Mo[i], j);

  (*S)[(*k)-i-1] = RSMatrixMultiply(vector);
    }

    for (i = 0; i < 20; i++)
    {
  A = h(2*i*RHO, Me, *k);
  B = ROL(h(2*i*RHO + RHO, Mo, *k), 8);
  K[2*i] = A+B;
  K[2*i+1] = ROL(A + 2*B, 9);
    }
}

/***********************************************************************
  TESTING FUNCTIONS AND STUFF STARTS HERE
***********************************************************************/

void printHex(BYTE b[], int lim)
{
  int i;
  for (i=0; i<lim;i++)
  printf("%02X", (u32)b[i]);
}

void toHex(BYTE *hex, char *buf, int lim) {
  /* put lim bytes from buf to hex to build a binary hex string */
    int i;
    for (i=0;i<lim;i++) {
      sprintf((char *)hex+i*2,"%02X", (BYTE)buf[i]);
      // printf("%02X %i\n", (BYTE)buf[i], i);
  }

}

// void fromHex( const char *pos, BYTE text[], int lim)
// {
  // int count;
//
  // for(count = 0; count < lim; count++) {
    // sscanf(pos, "%2hhx", &text[count]);
    // pos += 2;
  // }
// }

void Itest(int n) {
    BYTE ct[16], nct[16], k1[16], k2[16], k[32];

    uint32_t QF[4][256];
    int i;
    u32 *KS;
    uint32_t K[40];
    int Kk;

    memset(ct, 0, 16);
    memset(nct, 0, 16);
    memset(k1, 0, 16);
    memset(k2, 0, 16);

    for (i=0; i<49; i++)
    {
  memcpy(k, k1, 16);
  memcpy(k+16, k2, 16);

  keySched(k, n, &KS, K, &Kk);
  fullKey(KS, Kk, QF);
  free(KS);
  /*printSubkeys(K);*/
  memcpy(nct, ct, 16);
        // encrypt(K, QF, nct);
  printf("\nI=%d\n", i+1);
  printf("KEY=");
  printHex(k, n/8);
  printf("\n");
  printf("PT="); printHex(ct, 16); printf("\n");
  printf("CT="); printHex(nct, 16); printf("\n");
  memcpy(k2, k1, 16);
  memcpy(k1, ct, 16);
  memcpy(ct, nct, 16);
    }
}

/***********************************************************************
  Code for the Tcl extension
***********************************************************************/

int TwofishObjCmd(ClientData clientData, Tcl_Interp *interp,
      int objc, Tcl_Obj *CONST objv[])

{
  uint32_t *S;
  int k;
  int i;
  BYTE *buf;
  int len;
  int mode;
  Tcl_Obj *objPtr;
  uint8_t *tempiv;
  Tcl_HashEntry *entryPtr;
  int result;
  int index;

  TWOFISH_CTX *mp;

  static const char *subcommands[] = {
    "init", "encrypt", "decrypt", "delete", NULL };

  static const char *cipherMode[] = {
    "ecb", "cbc", NULL };

  typedef struct cmd_Def {
    char *usage;
    int minArgCnt;
    int maxArgCnt;
  } cmdDefinition;

  static cmdDefinition definitions[] = {
    {"init engine mode key ?iv?", 5, 6},
    {"encrypt engine data", 4, 4},
    {"decrypt engine data", 4, 4},
    {"delete engine", 3, 3}
  };

  #define TWOFISH_init 0
  #define TWOFISH_encrypt 1
  #define TWOFISH_decrypt 2
  #define TWOFISH_delete 3

  /* parse the Tcl command line for options */
  if (objc < 2) {
    Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?options?");
    return TCL_ERROR;
  }

  /* known subcommand? */
  result = Tcl_GetIndexFromObj(interp, objv[1], subcommands,
    "subcommand", TCL_EXACT, &index);

  if (result != TCL_OK) {return result;}

  /* correct count of parameters? */
  if ((objc < definitions[index].minArgCnt) ||
     (objc > definitions[index].maxArgCnt)) {
    Tcl_WrongNumArgs(interp, 1, objv, definitions[index].usage);
    return TCL_ERROR;
  }

  result = TCL_OK;

  switch (index) {

/* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */
    case TWOFISH_init: {
/* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */

// twofish_c init $this ecb $key
// twofish_c init $this cbc $key $iv

      mp = (TWOFISH_CTX *)ckalloc( sizeof(TWOFISH_CTX) );

      /* Validate the cipher mode */

      result = Tcl_GetIndexFromObj(interp, objv[3], cipherMode, "cipher mode", TCL_EXACT, &mode);

      if (result != TCL_OK) {return result;}

      /* get the name of the Twofish engine created by Itcl
       * and create a new hash entry pointing to a TWOFISH_CTX
       * structure containing pointers for mode, the keys and subkeys
       * arrays */


      int new;
      // new is set to 1 if a new entry was created and 0 if there was already an entry for key.
      entryPtr = Tcl_CreateHashEntry( &engines, Tcl_GetString(objv[2]), &new );

      if (new == 1) { Tcl_SetHashValue(entryPtr, mp); }

      switch (mode) {
        case CBC: {
          if (objc < 6) {
            Tcl_WrongNumArgs(interp, 3, objv, "handle key iv");
            // ckfree( (char *)mp );
            return TCL_ERROR;
          }
          mp->mode = CBC;
          memcpy(mp->iv, Tcl_GetByteArrayFromObj(objv[5], &len), 16);

          if (len != 16) {
            Tcl_SetResult(interp, "Error: wrong iv length", TCL_VOLATILE);
            return TCL_ERROR;
          }
          break;
        }
        case ECB: {
          mp->mode = ECB;
          break;
        }
      }

      /* take key from command line, create the full key and save it
       * directly in the CTX structure of mp */

      buf = Tcl_GetByteArrayFromObj(objv[4], &len);
      if (len > 32) {
        Tcl_SetResult(interp, "Error: wrong key length", TCL_VOLATILE);
      }
      keySched(buf, len*8, &S, mp->key32, &k);    // returns key words K[]], subkeys S[]
      fullKey(S, k, mp->subkeys);                 // create full subkeys
      free(S);

      Tcl_SetResult(interp, "INIT_OK", TCL_VOLATILE);

      return TCL_OK;
    }

  /* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */
    case TWOFISH_encrypt: {
  /* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */

      /* Tcl command: twofish_c encrypt $this $block */

      entryPtr = Tcl_FindHashEntry(&engines, Tcl_GetString(objv[2]));

      if (entryPtr == NULL) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("Error: encryption engine handle %s not found.", Tcl_GetString(objv[2])));
        return TCL_ERROR;
      }

      mp = Tcl_GetHashValue(entryPtr);

      /* We are writing into objv[3] so we have to take care that
       * this object is not shared by another process */

      objPtr = objv[3];

      if (Tcl_IsShared(objPtr)) {
        objPtr = Tcl_DuplicateObj(objPtr);
      }

      buf = Tcl_GetByteArrayFromObj(objPtr, &len);
      Tcl_InvalidateStringRep(objPtr);

      if (len%16) {
        Tcl_SetResult(interp, "Encrypt error: input length must be a multiple of 16 bytes.", TCL_VOLATILE);
        return TCL_ERROR;
      }

      if (CBC == mp->mode ) {

        for(i=0;i<len;i+=16) {
          encrypt(mp->key32, mp->subkeys, buf+i, mp->mode, mp->iv);
          memcpy(mp->iv, buf+i, 16);
        }

      } else {

        for(i=0;i<len;i+=16) {
          encrypt(mp->key32, mp->subkeys, buf+i, mp->mode, NULL);
        }

      }

      Tcl_SetObjResult(interp, objPtr);

      return TCL_OK;

    }
  /* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */
    case TWOFISH_decrypt: {
  /* +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ */

      // Tcl command: twofish_c decrypt $this $block

      entryPtr = Tcl_FindHashEntry(&engines, Tcl_GetString(objv[2]));

      if (entryPtr == NULL) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("Error: encryption engine handle %s not found.", Tcl_GetString(objv[2])));
        return TCL_ERROR;
      }

      mp = Tcl_GetHashValue(entryPtr);

      objPtr = objv[3];

      if (Tcl_IsShared(objPtr)) {
        objPtr = Tcl_DuplicateObj(objPtr);
      }

      buf = Tcl_GetByteArrayFromObj(objPtr, &len);
      Tcl_InvalidateStringRep(objPtr);

      if (len%16) {
        Tcl_SetResult(interp, "Error: bad data length, must be a multiple of 16 bytes.", TCL_VOLATILE);
        return TCL_ERROR;
      }

      if (CBC == mp->mode) {

        /* Concatenate initial IV and encrypted buffer data, so loop index
           pointer can access the proper data at the correct time.  Because CBC
           mode decryption for block I uses encrypted block I-1 as an IV, and
           because decrypt() operates in place, we have to make a copy of the
           encrypted data here using the local stack as memory
        */

        tempiv = alloca( 16 + len );
        memcpy(tempiv, mp->iv, 16);
        memcpy(tempiv+16, buf, len);

        for (i=0; i<len; i+=16) {
          decrypt(mp->key32, mp->subkeys, buf+i, mp->mode, tempiv+i);
        }

        /* save last encrypted block as IV for next decryption task */
        memcpy(mp->iv, tempiv+i, 16);

      } else {

        for (i=0; i<len; i+=16) {
          decrypt(mp->key32, mp->subkeys, buf+i, mp->mode, NULL);
        }

      }

      Tcl_SetObjResult(interp, objPtr);

      return TCL_OK;
    }

  /****************************************************************/
    case TWOFISH_delete: {
  /****************************************************************/

      // Tcl command: twofish_c delete $engine

      entryPtr = Tcl_FindHashEntry(&engines, Tcl_GetString(objv[2]));

      if (entryPtr == NULL) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("Error: encryption engine handle %s not found.", Tcl_GetString(objv[2])));
        return TCL_ERROR;
      }

      mp = Tcl_GetHashValue(entryPtr);
      ckfree ((char *)mp);
      Tcl_DeleteHashEntry(entryPtr);

      return TCL_OK;
    }

  }

  return TCL_OK;
}

/***********************************************************************
 Initialization for a Tcl extension
***********************************************************************/


int Twofish_Init(Tcl_Interp *interp) {

    if (Tcl_InitStubs(interp, "8.5", 0) == NULL) {
        return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, "twofish_c", TwofishObjCmd,
        (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    Tcl_InitHashTable( &engines, TCL_STRING_KEYS);

    return TCL_OK;

}

