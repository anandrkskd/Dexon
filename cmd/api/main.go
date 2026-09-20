// Command api is the client-facing REST server (see api/openapi.yaml).
//
// Responsibilities (see design docs before implementing):
//   - Authenticate requests via X-Dexon-Api-Key (api_keys table).
//   - Enforce quota (tiers.max_vms) before inserting a vms row.
//   - POST /vms: insert vms row (status=pending); DB trigger handles
//     pg_notify -- this binary does not need to notify anything itself.
//   - Support wait=true by subscribing to that VM's row changes and
//     holding the response open until a terminal status or timeout.
//   - DELETE /vms/{id}: call FleetControl.RequestDelete directly (see
//     proto/dexon_fleetcontrol.proto) -- do NOT write vms.status here.
//   - Never expose vms.host_id in any response.
//
// Depends on:
//   - Postgres (db/migrations/0001_init.sql)
//   - FleetControl gRPC client (proto/fleetcontrolv1, generated)
//   - Generated types from api/openapi.yaml (run `make gen-api`)
package main

func main() {
	// TODO: load config (internal/config)
	// TODO: connect to Postgres
	// TODO: dial FleetControl gRPC service
	// TODO: wire up HTTP router + generated handlers
	// TODO: start HTTP server
}
