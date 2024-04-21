#include "bytecode.h"
#include "vm.h"

VM load_vm(const char* path)
{
	FILE* file = fopen(path, "rb");
	if (!file)
		FATAL("[VM] File \"%s\" could not be opened", path);

	fseek(file, 0, SEEK_END);
	isize instrc = ftell(file) * sizeof(char) / sizeof(Instruction);
	rewind(file);

	Instruction* instrs = malloc(instrc);
	memcpy(instrs, file, instrc * sizeof(Instruction));

	fclose(file);
	return (VM){
		.instrc = instrc,
		.instrs = instrs,
	};
}

void free_vm(VM* vm)
{
	free(vm->instrs);
	vm->instrs = NULL;
	vm->instrc = 0;
}

/* -------------------------------------------------------------------- */

#define NEXT ci = vm->instrs[ip++];
void run_vm(VM* vm)
{
	static const void* op_table[] = {
		[NOP]  = &&op_nop,
		[JMP]  = &&op_jmp,
		[HALT] = &&op_halt,
	};

	static Instruction* ci;
	static int64  acc;
	static intptr ip;

op_nop:
op_jmp:
op_halt:

}
