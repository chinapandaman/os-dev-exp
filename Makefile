IMAGE ?= os-dev-exp

.PHONY: build-image dev-shell

build-image:
	docker build -t $(IMAGE) .

dev-shell: build-image
	docker run --rm -it \
		-v "$(CURDIR):/workspace" \
		-w /workspace \
		$(IMAGE) \
		bash
