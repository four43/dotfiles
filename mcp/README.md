# MCP Server Testing

This directory contains Docker Compose configuration for running MCP servers and a test script for validating their functionality.

## Running the Servers

Start all MCP servers:
```bash
docker-compose up -d
```

Check server status:
```bash
docker-compose ps
```

View logs:
```bash
docker-compose logs -f
```

## Testing the Servers

The test script connects to each MCP server via UNIX socket and lists available tools:

```bash
./test-mcp-servers.py
```

### What it tests:
- ✓ Socket connectivity
- ✓ MCP protocol initialization
- ✓ Tool listing
- ✓ Server information

### Tested Servers:
1. **Terraform AWS** - `/tmp/mcp-sockets/terraform-aws.sock`
2. **AWS Diagram** - `/tmp/mcp-sockets/aws-diagram.sock`
3. **AWS Documentation** - `/tmp/mcp-sockets/aws-documentation.sock`

## Troubleshooting

If the test fails:

1. **Socket not found**: Ensure Docker containers are running
   ```bash
   docker-compose ps
   docker-compose logs <service-name>
   ```

2. **Permission denied**: Check socket permissions
   ```bash
   ls -la /tmp/mcp-sockets/
   ```

3. **Connection refused**: Container may still be initializing
   ```bash
   docker-compose logs -f <service-name>
   ```

## Adding New Servers

To add a new MCP server to the test:

1. Add the service to `docker-compose.yml`
2. Expose it via UNIX socket in `/tmp/mcp-sockets/`
3. Add an entry to the `servers` dict in `test-mcp-servers.py`

Example:
```python
servers = {
    # ... existing servers ...
    "My New Server": "/tmp/mcp-sockets/my-server.sock",
}
```
