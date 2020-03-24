GO := go
GOFMT := gofmt
ARCH ?= $(shell go env GOARCH)
OS ?= $(shell go env GOOS)

.PHONY: all

#IMAGE_REPOSITORY_URL = dev-image.wanxingrowth.com/shoppingmall
BUILD_NUMBER = $(shell git rev-parse --short HEAD)
BUILD_TAG := $(shell date +%Y%m%d%H%M%S)

ifneq ($(shell uname), Darwin)
	EXTLDFLAGS = -extldflags "-static" $(null)
else
	EXTLDFLAGS =
endif

all: build test

build: build_service_cross_only

.PHONY: restful_doc

SED_PATH := $(shell which sed)
restful_doc:
	# swaggo need larger than 1.6
	swag init -g cmd/main.go -o pkg/restful/swaggerdocs
	if strings $(SED_PATH) | grep -q 'GNU'; then \
		$(SED_PATH) -i '/^\/\/ This file was generated by swaggo\/swag at/{n;d;}' pkg/restful/swaggerdocs/docs.go; \
		$(SED_PATH) -i '/^\/\/ This file was generated by swaggo\/swag at/d' pkg/restful/swaggerdocs/docs.go; \
	else \
		$(SED_PATH) -i '' '/^\/\/ This file was generated by swaggo\/swag at/{n;d;}' pkg/restful/swaggerdocs/docs.go; \
		$(SED_PATH) -i '' '/^\/\/ This file was generated by swaggo\/swag at/d' pkg/restful/swaggerdocs/docs.go; \
	fi

.PHONY: test
test:
	mkdir -p .test-result
	go test -cover -coverprofile cover.out -outputdir .test-result ./...
	go tool cover -html=.test-result/cover.out -o .test-result/coverage.html

.PHONY: build_service_local
build_service_local: restful_doc build_service_protos
	mkdir -p builds/debug
	go build -o builds/debug/service -ldflags '${EXTLDFLAGS}-X huaweiApi/pkg/utils/version.VersionDev=build.$(BUILD_NUMBER)' huaweiApi/cmd

.PHONY: build_service_cross
build_service_cross: restful_doc build_service_protos
	mkdir -p builds/release
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o builds/release/service -ldflags '${EXTLDFLAGS}-X github.com/kpaas-io/kpaas/pkg/utils/version.VersionDev=build.$(BUILD_NUMBER)' huaweiApi/cmd

.PHONY: build_service_cross_only
build_service_cross_only:
	mkdir -p builds/release
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o builds/release/service -ldflags '${EXTLDFLAGS}-X github.com/kpaas-io/kpaas/pkg/utils/version.VersionDev=build.$(BUILD_NUMBER)' huaweiApi/cmd

.PHONY: run_service_local
run_service_local: build_service_local
	# Use ./config/example.json copy to ./config/dev.json when first time debug
	builds/debug/service --log-level=debug --config-file=./config/dev.json

#build_service_image: build_service_cross
#	docker build -t $(IMAGE_REPOSITORY_URL)/service:$(BUILD_TAG) -f builds/docker/service/Dockerfile .
#
#push_service_image: build_service_image
#	docker push $(IMAGE_REPOSITORY_URL)/service:$(BUILD_TAG)

.PHONY: build_service_protos
build_service_protos:
	@sh builds/protos/protos.sh

.PHONY: pre_commit
pre_commit: test
	go fmt ./...
	go vet ./...
