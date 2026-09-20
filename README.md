# Dexon

A VM lifecycle control plane over KVM/QEMU: gRPC/REST orchestration,
async provisioning workflows, and host-agent-based hypervisor
management. Built as a portfolio project modeled on real compute
control planes (OpenStack Nova's component split, in particular),
deliberately without Kubernetes -- this operates a layer below it.

## Components (four separate binaries)

| Binary | Role |
|---|---|
| `cmd/api` | Client-facing REST API (`api/openapi.yaml`). Auth, quota, writes VM requests to Postgres. Never talks to agents directly. |
| `cmd/scheduler` | Wakes on pending requests (Postgres LISTEN/NOTIFY + poll fallback), makes placement decisions, dispatches via FleetControl. |
| `cmd/fleetmanager` | Owns the live agent registry (persistent gRPC streams) and is the sole writer of VM status once a VM leaves the scheduling stage. Exposes both the agent-facing stream service and the internal FleetControl service. |
| `cmd/agent` | Runs on each hypervisor host. Never writes to the DB. Reconciles libvirt's actual state against a locally cached desired state; executes commands; reports back. |

## Why two proto files

- `proto/dexon_agent.proto` -- Fleet manager \<-\> Agent. One persistent,
  agent-initiated, bidirectional stream per host.
- `proto/dexon_fleetcontrol.proto` -- Scheduler/API -> Fleet manager.
  Plain request/response gRPC, two callers (Scheduler for placement,
  API for deletes), imports `VMSpec` from the first file.

## Deliberately out of scope for v1

- **Networking**: every VM attaches to the host's default libvirt NAT
  bridge. No per-tenant networks, no `network_id`. A real system would
  need a dedicated network service (its own project-sized subsystem).
- **Multi-replica Scheduler/Fleet manager**: single instance of each
  for now. Running more than one Scheduler safely needs a DB-level
  claim (`SELECT ... FOR UPDATE SKIP LOCKED`) or leader election to
  avoid double-scheduling -- documented, not built.
- **Idempotency keys** on `POST /vms`: a retried request can currently
  create a duplicate VM. Known limitation.
- **DB-level write permission enforcement**: the write-boundary
  conventions documented in `db/migrations/0001_init.sql` (who writes
  which columns) are enforced by code review, not Postgres roles/grants.

## Local dev setup

```bash
docker compose -f deploy/docker-compose.yml up -d   # Postgres, Prometheus, Grafana
make migrate-up                                      # apply db/migrations/0001_init.sql
make gen                                             # generate proto + API types (see below)
```

### Codegen prerequisites

```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
go install github.com/deepmap/oapi-codegen/v2/cmd/oapi-codegen@latest
# protoc itself: apt install protobuf-compiler / brew install protobuf
```

> **Open decision**: `make gen-api` currently targets `chi-server`.
> Confirm the HTTP router choice (chi / gin / net-http) before relying
> on the generated server interface -- change the `-generate` flag in
> the Makefile accordingly if it's not chi.

## Running (once implemented)

```bash
go run ./cmd/fleetmanager &
go run ./cmd/scheduler &
go run ./cmd/api &
go run ./cmd/agent   # one per simulated host
```
