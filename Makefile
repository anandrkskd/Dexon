.PHONY: gen-proto gen-api gen migrate-up

# Requires: protoc, protoc-gen-go, protoc-gen-go-grpc, oapi-codegen
# (see setup notes in README.md)

gen-proto:
	protoc -I proto \
		--go_out=. --go_opt=module=github.com/anandrkskd/Dexon \
		--go-grpc_out=. --go-grpc_opt=module=github.com/anandrkskd/Dexon \
		proto/dexon_agent.proto proto/dexon_fleetcontrol.proto

gen-api:
	oapi-codegen -generate types,chi-server -o internal/apigen/dexon_api.gen.go -package apigen api/openapi.yaml

gen: gen-proto gen-api

migrate-up:
	psql "$${DATABASE_URL:-postgres://dexon:dexon@localhost:5432/dexon?sslmode=disable}" -f db/migrations/0001_init.sql
