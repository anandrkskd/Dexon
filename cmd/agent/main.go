// Command agent runs on each hypervisor host. It never writes to the
// database directly -- it only observes libvirt, reports to Fleet
// manager, and executes commands it's given.
//
// Lifecycle:
//   1. Dial Fleet manager, open the persistent Connect stream.
//   2. Send RegisterHost (cpu_cores, memory_bytes, hyperthreading).
//   3. Receive a DesiredStateSnapshot; cache it in memory.
//   4. Loop forever (every N seconds):
//        - query libvirt for actual running VMs
//        - compare against cached desired state
//        - in sync -> send Heartbeat + MetricsReport
//        - drift   -> send DriftReport (do NOT self-heal)
//   5. Concurrently: receive commands (CreateVM/DeleteVM) on the same
//      stream, process them SEQUENTIALLY in receive order (no
//      per-command goroutines -- see fleetmanager main.go for why),
//      update the local cache, call libvirt, then send a
//      CommandResult (success/failure) back.
//   6. On stream disconnect/reconnect: re-register, and expect Fleet
//      manager to re-push a full DesiredStateSnapshot (not
//      incremental) so the cache can't silently miss a missed change.
//
// Depends on:
//   - libvirt-go (or equivalent) for KVM/QEMU access
//   - Generated code from proto/dexon_agent.proto
package main

func main() {
	// TODO: load config (host capacity, fleet manager address)
	// TODO: connect to libvirt
	// TODO: dial Fleet manager, open Connect stream, register
	// TODO: receive initial DesiredStateSnapshot, cache it
	// TODO: start reconcile loop (ticker, every N seconds)
	// TODO: start command receive loop (sequential per stream)
}
