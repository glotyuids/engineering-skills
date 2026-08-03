# Pack: Infrastructure (vendor-neutral)

The delivery path from source to a running workload: the Make entrypoint contract, container build rules, Terraform, Ansible, Kubernetes/Helm, and secrets.

## Skills

- [`cicd-build-deploy`](cicd-build-deploy/SKILL.md)
- [`terraform-conventions`](terraform-conventions/SKILL.md)
- [`ansible-deploy`](ansible-deploy/SKILL.md)
- [`kubernetes-helm`](kubernetes-helm/SKILL.md)
- [`makefile-conventions`](makefile-conventions/SKILL.md)
- [`secrets-management`](secrets-management/SKILL.md)

## Expects

A cloud vendor pack (or your own equivalent) to resolve the capabilities below.

## Soft companions

`cloud-yandex` — companions are suggestions, not requirements. Every skill here works with the
companion pack absent; cross-pack references are written to degrade gracefully.

## Notes

Every skill here is written against capabilities, never a provider:

| Capability | Meaning |
|---|---|
| `MANAGED_K8S` | the Kubernetes cluster the workloads run on |
| `REGISTRY` | where container images are pushed and pulled from |
| `SECRET_MANAGER` | the system of record for secret values |
| `MANAGED_PG` | the managed PostgreSQL instance |
| `TFSTATE_BACKEND` | remote Terraform state storage with locking |
| `LB` | ingress / load balancing |
| `IAM` | identity for CI and operators |

Install `cloud-yandex` to resolve them, or write your own vendor skill — see CONTRIBUTING.md.

---

Install: `/plugin install infra@engineering-skills`, or
`./scripts/install.sh <project> --packs infra`, or ask your agent to install the
**infra** pack from `glotyuids/engineering-skills`.
