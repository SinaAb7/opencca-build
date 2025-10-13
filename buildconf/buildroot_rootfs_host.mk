#!/usr/bin/make -f

# DEBOS_DIR
include env.mk

.PHONY: debos clean

build: host ## See host

host: ## build rootfs for host
	cd $(BUILDROOT_DIR) && \
	$(MAKE) rock5b_defconfig ARCH=$(ARCH) \
		CROSS_COMPILE=$(CROSS_COMPILE) 

	cd $(BUILDROOT_DIR) && \
	$(MAKE) 
		


 
