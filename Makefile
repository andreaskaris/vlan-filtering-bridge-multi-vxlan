TOPO   ?= pe-lab.clab.yml
CLAB   ?= containerlab
DOCKER ?= docker

.PHONY: deploy destroy redeploy cleanup test

deploy:
	$(CLAB) deploy -t $(TOPO)

destroy:
	$(CLAB) destroy -t $(TOPO)

redeploy: destroy deploy

# Same as destroy, but also removes the lab's generated directory.
cleanup:
	$(CLAB) destroy -t $(TOPO) --cleanup

test:
	DOCKER="$(DOCKER)" ./scripts/test.sh
