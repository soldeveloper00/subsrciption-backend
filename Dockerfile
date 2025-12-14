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

# Install runtime dependencies (SSL libraries)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/target/release/trading-signals-backend .

# Expose the port your app listens on
EXPOSE 8080

# Run the binary
CMD ["./trading-signals-backend"]