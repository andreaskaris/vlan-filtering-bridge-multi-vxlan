TOPO  ?= pe-lab.clab.yml
CLAB  ?= containerlab

.PHONY: deploy destroy redeploy cleanup

deploy:
	$(CLAB) deploy -t $(TOPO)

destroy:
	$(CLAB) destroy -t $(TOPO)

redeploy: destroy deploy

# Same as destroy, but also removes the lab's generated directory.
cleanup:
	$(CLAB) destroy -t $(TOPO) --cleanup
