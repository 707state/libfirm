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
 * @brief   yet another set implementation
 * @author  Florian
 * @date    Mon 18 Oct 2004
 * @version $Id$
 */
#ifndef FIRM_ANA2_QSET_H
#define FIRM_ANA2_QSET_H

# ifndef TRUE
#  define TRUE 1
#  define FALSE 0
# endif /* nof defined TRUE */

/* define this as needed */
# define COMPARE(A,B)       (A<B)
# define EQUAL(A,B)       (A==B)
/* typedef unsigned int sortable_t; */
typedef void* sortable_t;

struct obstack;                 /* forward decl */

typedef struct qset_str
{
  struct obstack *obst;
  sortable_t *values;
  int n_slots;
  int n_elems;
  int is_sorted;
  int cursor;                   /* for qset_start/qset_next */
  int id;
} qset_t;


/* QSET INTERFACE */

/* Allocate a new qset with initial space for up to n_elems.
   If a non-NULL obstack is given, it is used for all allocations of this qset
   and must be initialised and deleted by the user of the qset. */
qset_t *qset_new (const int, struct obstack*);

/* Sort the entries of the given qset. */
void qset_sort (qset_t*);

/* Compact a qset to take up no more space than required. */
void qset_compact (qset_t*);

/* Free the memory associated with the given qset */
void qset_delete (qset_t*);

/* Test whether the given qset contains the given value. */
int qset_contains (qset_t*, sortable_t);

/* Delete the given value from the given qset (if it exists) */
void qset_remove (qset_t*, sortable_t);

/* Insert the given elem into the given qset; return nonzero iff any involved values change. */
int qset_insert (qset_t*, sortable_t);

/* Insert all elems of qset2 into qset1. qset2 is deleted; return
   nonzero iff any involved values change. */
int qset_insert_all (qset_t*, qset_t*);

/* Compare two qsets. */
int qset_compare (qset_t*, qset_t*);

/* Returns the union of two qsets. */
qset_t *qset_union (qset_t *qset1, qset_t *qset2);

/* Report the size of the given qset. */
int qset_size (qset_t *qset);

/* Print the given qset to the given stream. */
void qset_print (qset_t*, FILE*);

/* Check wether the given qset is empty */
int qset_is_empty (qset_t*);

/*
   Iterate over a qset
*/
/* initialise the iteration, return the first element */
sortable_t *qset_start (qset_t*);
/* step to the next element, return NULL iff no more elems are available */
sortable_t *qset_next (qset_t*);

#endif

/*
 $Log$
 Revision 1.5  2004/11/30 14:47:11  liekweg
 insert report changes

 Revision 1.4  2004/11/24 14:53:56  liekweg
 Bugfixes

 Revision 1.3  2004/11/18 16:35:46  liekweg
 Added unique ids for debugging

 Revision 1.2  2004/11/08 12:32:00  liekweg
 Moved q_* methods into private section

 Revision 1.1  2004/11/04 14:55:13  liekweg
 added qset


*/
