#define CLIB_IMPLEMENTATION
#include "clib/clib.h"

#include "vm.h"

int main(int argc, const char** argv)
{
	load_vm("test.konb");
}
