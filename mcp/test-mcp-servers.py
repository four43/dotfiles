#!/usr/bin/env python3
"""
Test script for MCP servers exposed via UNIX sockets.
Connects to each server and lists available tools.
"""

import asyncio
import json
import socket
import sys
from pathlib import Path
from typing import Dict, List, Any


class MCPClient:
    """Simple MCP client that communicates over UNIX sockets."""

    def __init__(self, socket_path: str):
        self.socket_path = socket_path
        self.sock = None
        self.request_id = 0

    async def connect(self):
        """Connect to the UNIX socket."""
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            self.sock.connect(self.socket_path)
            self.sock.setblocking(False)
            print(f"✓ Connected to {self.socket_path}")
            return True
        except (FileNotFoundError, ConnectionRefusedError) as e:
            print(f"✗ Failed to connect to {self.socket_path}: {e}")
            return False

    async def send_request(self, method: str, params: Dict = None) -> Dict:
        """Send a JSON-RPC request and receive response."""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "id": self.request_id,
            "method": method,
        }
        if params:
            request["params"] = params

        # Send request
        request_data = json.dumps(request) + "\n"
        self.sock.sendall(request_data.encode())

        # Receive response
        loop = asyncio.get_event_loop()
        response_data = b""
        while True:
            try:
                chunk = await loop.sock_recv(self.sock, 4096)
                if not chunk:
                    break
                response_data += chunk
                # Check if we have a complete JSON object
                try:
                    response = json.loads(response_data.decode())
                    return response
                except json.JSONDecodeError:
                    continue
            except BlockingIOError:
                await asyncio.sleep(0.01)

        if response_data:
            return json.loads(response_data.decode())
        return {}

    async def initialize(self) -> Dict:
        """Initialize the MCP connection."""
        return await self.send_request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {
                "name": "mcp-test-client",
                "version": "1.0.0"
            }
        })

    async def list_tools(self) -> List[Dict[str, Any]]:
        """List available tools from the MCP server."""
        response = await self.send_request("tools/list")
        if "result" in response and "tools" in response["result"]:
            return response["result"]["tools"]
        return []

    def close(self):
        """Close the socket connection."""
        if self.sock:
            self.sock.close()


async def test_server(name: str, socket_path: str):
    """Test a single MCP server."""
    print(f"\n{'='*60}")
    print(f"Testing: {name}")
    print(f"Socket: {socket_path}")
    print(f"{'='*60}")

    # Check if socket exists
    if not Path(socket_path).exists():
        print(f"✗ Socket file does not exist: {socket_path}")
        print(f"  Make sure the server is running!")
        return False

    client = MCPClient(socket_path)

    try:
        # Connect
        if not await client.connect():
            return False

        # Initialize
        print("Initializing connection...")
        init_response = await client.initialize()
        if "result" in init_response:
            print(f"✓ Initialized successfully")
            server_info = init_response["result"].get("serverInfo", {})
            if server_info:
                print(f"  Server: {server_info.get('name', 'Unknown')} v{server_info.get('version', 'Unknown')}")
        else:
            print(f"✗ Initialization failed: {init_response.get('error', 'Unknown error')}")
            return False

        # List tools
        print("\nListing tools...")
        tools = await client.list_tools()

        if tools:
            print(f"✓ Found {len(tools)} tools:")
            for tool in tools:
                print(f"\n  • {tool.get('name', 'Unknown')}")
                if 'description' in tool:
                    desc = tool['description']
                    # Truncate long descriptions
                    if len(desc) > 100:
                        desc = desc[:97] + "..."
                    print(f"    {desc}")
        else:
            print(f"✗ No tools found or failed to list tools")
            return False

        return True

    except Exception as e:
        print(f"✗ Error testing server: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        client.close()


async def main():
    """Main test function."""
    print("MCP Server Test Script")
    print("=" * 60)

    # Define servers to test
    servers = {
        "Terraform AWS": "/tmp/mcp-sockets/terraform-aws.sock",
        "AWS Diagram": "/tmp/mcp-sockets/aws-diagram.sock",
        "AWS Documentation": "/tmp/mcp-sockets/aws-documentation.sock",
    }

    results = {}
    for name, socket_path in servers.items():
        success = await test_server(name, socket_path)
        results[name] = success
        await asyncio.sleep(0.5)  # Brief pause between tests

    # Summary
    print(f"\n{'='*60}")
    print("Test Summary")
    print(f"{'='*60}")

    for name, success in results.items():
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"{status}: {name}")

    passed = sum(1 for s in results.values() if s)
    total = len(results)
    print(f"\nResults: {passed}/{total} servers passed")

    return 0 if passed == total else 1


if __name__ == "__main__":
    try:
        exit_code = asyncio.run(main())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        sys.exit(1)
