// Package config centralizes environment-variable loading shared
// across all four Dexon binaries (api, scheduler, fleetmanager, agent).
package config

// TODO: define a struct per binary (e.g. APIConfig, SchedulerConfig,
// FleetManagerConfig, AgentConfig) and a Load*() function per struct
// that reads from environment variables, with sane local-dev defaults
// (e.g. DATABASE_URL=postgres://localhost:5432/dexon?sslmode=disable).
