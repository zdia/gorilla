/*
 * stretch.c
 *
 * helper extension to create a stretched sha256 key for Password
 * Gorilla.  Utilizes the API provided by Tcllib's FreeBSD
 * implementation in file sha256.c
 *
 * Tcl call:
 * computeStretchedKey_c $password$salt $iter $blocksize "pvar"
 *
 * returns the stretched key to the Tcl stack
 *
 * gcc -shared -fPIC -DRUNTIME_ENDIAN -Wall -I ~/Programme/Active-Tcl-8.5/include/ -o stretchkey.so stretch.c sha256.c
 *
 * actually (30.09.2013) optimized with:
 *
 * gcc -Wall -shared -fPIC O9 -fomit-frame-pointer -funroll-loops -fschedule-insns2 \
    -fexpensive-optimizations -DRUNTIME_ENDIAN -DUSE_TCL_STUBS \
		-I ~/Programme/Active-Tcl-8.5/include/ -o stretchkey.so stretch.c sha256.c \
		-L ~/Programme/Active-Tcl-8.5/lib/ -ltclstub8.5

 * This program is free software; you can redistribute it and/or modify
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

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <tcl.h>
#include "sha256.h"

/***********************************************************************/
int StretchKeyObjCmd(ClientData clientData, Tcl_Interp *interp,
    int objc, Tcl_Obj *CONST objv[])
{

  static SHA256Context hashContext;
  uint8_t hash[SHA256_HASH_SIZE];
  uint8_t *data;
  char *pvarName;
  int i,j;
  int size;
  int iter;
  int blocks, blocksize, remain, pvar;

  if (objc != 5) {
    Tcl_WrongNumArgs(interp, 1, objv, "passwordsalt iterations blocksize pvarName");
    return TCL_ERROR;
  }

  pvarName = Tcl_GetStringFromObj(objv[4], &size);

  if ( Tcl_LinkVar(interp, pvarName,  (char *)&pvar, TCL_LINK_INT) ) {
    Tcl_SetResult(interp, "Error: could not link passed variable", TCL_VOLATILE);
    return TCL_ERROR;
  }

  data = Tcl_GetByteArrayFromObj(objv[1], &size);
// printf("size0=%i\n", size);

 // for (i = 0; i < size;) {
    // printf ("%02x", data[i++]);
  // }
  // printf ("\n");

  memset(hash, 0, SHA256_HASH_SIZE);

  SHA256Init (&hashContext);
  SHA256Update (&hashContext, data, size);
  SHA256Final (&hashContext, hash);

// puts("Xi");
  // for (i = 0; i < SHA256_HASH_SIZE;) {
    // printf ("%02x", hash[i++]);
  // }
  // printf ("\n");

  Tcl_GetIntFromObj(interp, objv[2], &iter);
  Tcl_GetIntFromObj(interp, objv[3], &blocksize);

  blocks = iter / blocksize;

  for (i = 0; i < blocks; i++) {
    for (j = 0; j < blocksize; j++) {
      SHA256Init (&hashContext);
      SHA256Update (&hashContext, hash, SHA256_HASH_SIZE);
      SHA256Final (&hashContext, hash);
    }
    pvar = 100*j*blocksize/iter;
    Tcl_UpdateLinkedVar(interp, pvarName);
  }

  remain = iter - (i*blocksize);

  for ( i = 0; i < remain; i++) {
      SHA256Init (&hashContext);
      SHA256Update (&hashContext, hash, SHA256_HASH_SIZE);
      SHA256Final (&hashContext, hash);
    }

  pvar = 100;
  Tcl_UpdateLinkedVar(interp, pvarName);
  Tcl_UnlinkVar(interp, pvarName);

  Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(hash, SHA256_HASH_SIZE));

  return TCL_OK;
}

/***********************************************************************
 Initialization for a Tcl extension
***********************************************************************/


int Stretchkey_Init(Tcl_Interp *interp) {

    if (Tcl_InitStubs(interp, "8.5", 0) == NULL) {
        return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, "computeStretchedKey_c", StretchKeyObjCmd,
        (ClientData)NULL, (Tcl_CmdDeleteProc *)NULL);

    return TCL_OK;

}
