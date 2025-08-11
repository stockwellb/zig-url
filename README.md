# zig-url

A HTTP client library for Zig, inspired by libcurl.

## Project Status

🚧 **Early Development** - This project is in very early stages. Basic functionality is not yet implemented.

## Goals

- Pure Zig HTTP client library
- Simple, safe API
- Support for HTTP/HTTPS
- URL parsing and manipulation
- Memory-efficient design

## Getting Started

### Building

```bash
zig build
```

### Running Tests

```bash
zig build test
```

### Running Examples

```bash
# Build all examples
zig build examples

# Run individual examples
./zig-out/bin/simple_get
./zig-out/bin/url_parse
```

## Development Roadmap

1. **Phase 1**: URL parsing
2. **Phase 2**: Basic HTTP GET requests
3. **Phase 3**: HTTP POST and other methods
4. **Phase 4**: HTTPS support
5. **Phase 5**: Advanced features (cookies, redirects, etc.)

## License

MIT (to be added)