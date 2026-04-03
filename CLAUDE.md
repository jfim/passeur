# Passeur

Self-hosted Elixir MCP server framework with OAuth 2.1 and Dynamic Client Registration (DCR) support. Designed to work with claude.ai, Claude Desktop, and Claude Code.

## Development

- Elixir/Erlang managed via asdf (see `.tool-versions`)
- Run `mix deps.get` to install dependencies
- Run `mix test` to run tests
- Run `mix format` to format code

## Architecture

- MCP server implementing the Model Context Protocol
- OAuth 2.1 authorization server for authentication
- Dynamic Client Registration (RFC 7591) for automatic client onboarding
