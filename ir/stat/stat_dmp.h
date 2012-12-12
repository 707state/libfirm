/*
 * This file is part of libFirm.
 * Copyright (C) 2012 University of Karlsruhe.
 */

/**
 * @file
 * @brief   Statistics for Firm. Dumping.
 * @author  Michael Beck
 */
#ifndef FIRM_STAT_STAT_DMP_H
#define FIRM_STAT_STAT_DMP_H

#include "firmstat_t.h"

/**
 * The simple human readable dumper.
 */
extern const dumper_t simple_dumper;

/**
 * the comma separated list dumper
 *
 * @note Limited capabilities, mostly for the Firm paper
 */
extern const dumper_t csv_dumper;

#endif /* FIRM_STAT_STAT_DMP_H */
