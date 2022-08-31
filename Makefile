
testBlueshmem: testBlueshmem.bsv Blueshmem.bsv blueshmem.c
	bsc -sim -I ./ -g mkTestBlueshmem -u testBlueshmem.bsv
	CFLAGS=-pthread;bsc -verbose -sim -e mkTestBlueshmem -o testBlueshmem -Xc -pthread blueshmem.c

.PHONY: run
run: testBlueshmem
	./testBlueshmem

.PHONY: clean
clean:
	rm -f *.bo *.ba *.so *.o imported_BDPI_functions.h mkTestBlueshmem.cxx mkTestBlueshmem.h model_* testBlueshmem *~
