# Stage 1: Build
FROM rust:1-slim AS builder

# Install OpenSSL development libraries AND pkg-config
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Build the application
RUN cargo build --release

# Stage 2: Run
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy ALL release files
COPY --from=builder /app/target/release/ ./

# Find and set executable
RUN chmod +x $(find . -maxdepth 1 -type f -executable | head -1)

# Expose the port
EXPOSE 8080

# Run the binary (automatically finds it)
CMD ["sh", "-c", "./$(find . -maxdepth 1 -type f -executable | head -1 | xargs basename)"]
