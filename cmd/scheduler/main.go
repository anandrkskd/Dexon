// Command scheduler makes placement decisions for pending VMs.
//
// Responsibilities:
//   - LISTEN on the 'vm_pending' Postgres channel; also run a periodic
//     poll (e.g. every 30s) as a fallback in case a notification is
//     ever missed -- never rely on LISTEN/NOTIFY alone.
//   - For each pending VM: call FleetControl.GetAvailableHosts, run
//     placement logic, pick a host.
//   - Write vms.host_id and vms.status='scheduled' (this is the only
//     place these columns are written).
//   - Call FleetControl.Dispatch with the chosen host_id + VMSpec.
//     Remember: converting flavor -> VMSpec (including the
//     memory_mb -> memory_bytes unit conversion) happens here.
//   - Does NOT write vms.status to 'running'/'failed'/'deleted' --
//     that's Fleet manager's job once CommandResult comes back.
//
// Depends on:
//   - Postgres (db/migrations/0001_init.sql)
//   - FleetControl gRPC client (proto/fleetcontrolv1, generated)
package main

func main() {
	// TODO: load config
	// TODO: connect to Postgres, start LISTEN on 'vm_pending'
	// TODO: start periodic poll fallback loop
	// TODO: dial FleetControl gRPC service
	// TODO: placement logic
}
