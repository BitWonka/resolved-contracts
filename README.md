# Resolved Contracts

A minimal smart contracts repo for the Resolved project, built with Foundry. It contains the core vault contracts and a simple deployment script.

## Contracts
- `WstResolv.sol` – Main vault wrapper for stResolv.

See `src/` for sources and `test/` for Forge tests.

## Prerequisites
- Foundry (forge, cast, anvil): https://book.getfoundry.sh/getting-started/installation
- Node

## Setup
1. Install submodules and dependencies:
   ```sh
   git submodule update --init --recursive
   ```
2. Copy environment file and fill values as needed:
   ```sh
   cp .env.example .env
   # edit .env
   ```

## Build & Test
- Build:
  ```sh
  forge build
  ```
- Test:
  ```sh
  forge test -vvv
  ```
- Format:
  ```sh
  forge fmt
  ```

## Local Node (optional)
Start a local Anvil node:
```sh
anvil
```

## Deploy
Example deployment of the WstResolv script:
```sh
forge script script/WstResolv.s.sol:DeployWstResolv \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Notes
- OpenZeppelin and forge-std are included via `lib/`.
- Remappings are managed in `foundry.toml` and `remappings.txt`.

## License
MIT (unless stated otherwise in individual files).
