#ifndef VM_H
#define VM_H

#include "clib/clib.h"
#include "bytecode.h"

typedef struct VM {
	isize instrc;
	Instruction* instrs;
} VM;

VM   load_vm(const char* path);
void free_vm(VM* vm);
void run_vm(VM* vm);

#endif
