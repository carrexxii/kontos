#ifndef OPS_H
#define OPS_H

#include "clib/clib.h"

typedef enum Op {
	NOP,
	CADDI, CADDF, RADDI, RADDF,
	JMP,
	HALT,
} Op;

typedef struct Instruction {
	byte code;
	uint oper: 24;
} Instruction;

#endif
