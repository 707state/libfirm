/* -*- c -*- */

/*
 * Copyright (C) 1995-2007 University of Karlsruhe.  All right reserved.
 *
 * This file is part of libFirm.
 *
 * This file may be distributed and/or modified under the terms of the
 * GNU General Public License version 2 as published by the Free Software
 * Foundation and appearing in the file LICENSE.GPL included in the
 * packaging of this file.
 *
 * Licensees holding valid libFirm Professional Edition licenses may use
 * this file in accordance with the libFirm Commercial License.
 * Agreement provided with the Software.
 *
 * This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
 * WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE.
 */

/**
 * @file
 * @brief   Compute rough approximations of pointer types
 * @author  Florian
 * @date    Mon 18 Oct 2004
 * @version $Id$
 */
# ifndef FIRM_ANA2_TYPALISE_H
# define FIRM_ANA2_TYPALISE_H

# include "lset.h"

# include "type.h"
# include "irnode.h"

/*
  Data Types and Structures
*/
typedef enum typalise_kind_enum {
  type_invalid = 0,             /* invalid (only set at deletion time) */
  type_exact = 1,               /* this and only this type (res.type) */
  type_types = 2,               /* these types (res.types) */
  type_type  = 3                /* this type and sub types (res.type) */
} typalise_kind;

typedef struct typalise
{
  typalise_kind kind;
  union {
    ir_type *type;              /* for kind == kind_exact and kind == kind_type */
    lset_t *types;              /* for kind == kind_types */
  } res;
  int id;
} typalise_t;

/*
  Protos
*/
/**
   Given a set of graphs and a typalise_t,  return the method (s) in
   the set that are supported by the typalise_t.  Also, deallocates
   the given set.
*/
lset_t *filter_for_ta (lset_t*, typalise_t*);

/**
   For the given ptr, do a quick check about what (class) types may be
   brought along on it.
*/
typalise_t *typalise (ir_node*);

/*
  Initialise the Typalise module
*/
void typalise_init (void);

# endif


/*
  $Log$
  Revision 1.4  2006/01/13 21:54:03  beck
  renamed all types 'type' to 'ir_type'

  Revision 1.3  2005/03/22 13:56:09  liekweg
  "small" fix for exception b/d

  Revision 1.2  2004/10/21 11:11:21  liekweg
  whitespace fix

  Revision 1.1  2004/10/21 11:09:37  liekweg
  Moved memwalk stuf into irmemwalk
  Moved lset stuff into lset
  Moved typalise stuff into typalise


 */
