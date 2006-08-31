#include "benodesets.h"
#include "irnode_t.h"

/*
 * Calculates a hash value for a node.
 *
 * Use its node number
 */
unsigned nodeset_hash(const ir_node *n) {
	return (unsigned)get_irn_idx(n);
}
