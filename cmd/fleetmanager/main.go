// Command fleetmanager owns the live agent registry and is the sole
// writer of vms.status once a VM leaves pending/scheduled/provisioning.
//
// Exposes TWO gRPC services -- see proto/:
//   1. FleetManager (dexon_agent.proto) -- agent-facing. Agents dial in
//      and hold one persistent bidirectional stream open for their
//      lifetime (Connect rpc). On connect: expect RegisterHost first,
//      persist/update the hosts row, then push a DesiredStateSnapshot.
//      Route CommandResult/DriftReport/Heartbeat/MetricsReport messages
//      from that stream to DB writes / the in-memory registry.
//   2. FleetControl (dexon_fleetcontrol.proto) -- internal-facing.
//      Called by Scheduler (GetAvailableHosts, Dispatch) and by API
//      (RequestDelete). Dispatch/RequestDelete responses are acks only
//      -- they do not mean the VM reached its final state.
//
// Process commands to a given agent stream in the order received (do
// not spawn a goroutine per command) -- this is what prevents a
// DeleteVM racing an in-flight CreateVM for the same vm_id.
//
// Depends on:
//   - Postgres (db/migrations/0001_init.sql)
//   - Generated code from proto/dexon_agent.proto and
//     proto/dexon_fleetcontrol.proto (run `make gen-proto`)
package main

func main() {
	// TODO: load config
	// TODO: connect to Postgres
	// TODO: start agent-facing gRPC server (FleetManager service)
	// TODO: start internal gRPC server (FleetControl service)
	// TODO: in-memory registry of connected agents/streams
}
