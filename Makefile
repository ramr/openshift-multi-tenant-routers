#! /usr/bin/env make


all:	build

build:
	@echo "  - Building nodejs-header-echo ... "
	(cd nodejs-header-echo &&  \
	   git submodule update --init --recursive && make)


demo:	build
	@echo ""
	@echo "  - Running demo script ... "
	( ./bin/demo )


clean:
	@echo "  - Cleaning up test environment ... "
	( ./bin/demo --cleanup)


debug:	build
	@echo ""
	@echo "  - Running demo script in debug ... "
	( ./bin/demo -x )
