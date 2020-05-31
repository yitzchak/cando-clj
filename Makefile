.PHONY: build run debug push

build:
	docker build --network=host --tag=yitzchak/cando-clj:latest .

run:
	docker run --network=host -it yitzchak/cando-clj:latest

debug:
	docker run --network=host -it yitzchak/cando-clj:latest bash

push:
	docker push yitzchak/cando-clj:latest
