# <PROJECT> — root Makefile.
#
# The single entrypoint for local development and for deployment. Target NAMES are an
# interface that skills, CI and humans all depend on — keep them stable even when the
# implementation behind them changes. Per-component local targets live in
# <component>/Makefile.

.PHONY: help modules build test vet lint fmt tidy clean check \
        deploy secrets-sync status logs restart rollback \
        terraform-init terraform-plan terraform-apply terraform-output

# --- Discovery -------------------------------------------------------------
# Modules are discovered from the filesystem, not hand-listed: adding a component
# needs no Makefile edit. Adapt the find expression to the project's layout.
MODULES := $(shell find . -name go.mod -maxdepth 3 -exec dirname {} \; 2>/dev/null | sort)

# --- Parameters ------------------------------------------------------------
ENV ?= prod
DEPLOY_DIR := infra/ansible

## help: Show this help
help:
	@echo "<PROJECT> — root Makefile"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'
	@echo ""
	@echo "Modules discovered:"
	@for m in $(MODULES); do echo "  - $$m"; done

## modules: List discovered modules
modules:
	@for m in $(MODULES); do echo "$$m"; done

# --- Local development -----------------------------------------------------

## build: Build every module — produces the artifacts
build:
	@set -e; for m in $(MODULES); do echo "==> build $$m"; (cd $$m && go build ./...); done

## test: Test every module
test:
	@set -e; for m in $(MODULES); do echo "==> test $$m"; (cd $$m && go test -race ./...); done

## vet: Static analysis over every module
vet:
	@set -e; for m in $(MODULES); do echo "==> vet $$m"; (cd $$m && go vet ./...); done

## lint: Lint every module
lint:
	@which golangci-lint > /dev/null || (echo "golangci-lint not installed" && exit 1)
	@set -e; for m in $(MODULES); do echo "==> lint $$m"; (cd $$m && golangci-lint run ./...); done

## fmt: Format every module
fmt:
	@set -e; for m in $(MODULES); do (cd $$m && go fmt ./...); done

## tidy: Tidy dependencies in every module
tidy:
	@set -e; for m in $(MODULES); do (cd $$m && go mod tidy); done

## check: The gate — everything that must pass before claiming work is done
check: fmt build vet test

## clean: Remove build artifacts
clean:
	@rm -rf ./bin ./dist

# --- Operations ------------------------------------------------------------
# Every kubectl/helm call underneath these MUST pass an explicit context — never rely
# on the current kubeconfig context.

## secrets-sync: Push local secret values into the secret manager (ENV=prod)
secrets-sync:
	@test -f .secrets.$(ENV) || (echo "missing .secrets.$(ENV) — copy .secrets.example and fill it" && exit 1)
	@echo "TODO: sync .secrets.$(ENV) into the secret manager"

## deploy: Deploy to ENV (default prod)
deploy:
	@echo "TODO: run the deploy playbook in $(DEPLOY_DIR) for ENV=$(ENV)"

## status: Show deployed workload status for ENV
status:
	@echo "TODO: status for ENV=$(ENV)"

## logs: Tail logs for SERVICE in ENV
logs:
	@test -n "$(SERVICE)" || (echo "usage: make logs SERVICE=<name>" && exit 1)
	@echo "TODO: logs for $(SERVICE) in ENV=$(ENV)"

## rollback: Roll back SERVICE in ENV to the previous release
rollback:
	@test -n "$(SERVICE)" || (echo "usage: make rollback SERVICE=<name>" && exit 1)
	@echo "TODO: rollback $(SERVICE) in ENV=$(ENV)"

## terraform-plan: Plan infrastructure changes for ENV
terraform-plan:
	@echo "TODO: terraform plan for ENV=$(ENV)"

## terraform-apply: Apply infrastructure changes for ENV
terraform-apply:
	@echo "TODO: terraform apply for ENV=$(ENV)"
