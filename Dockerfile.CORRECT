# Stage 1: Build
FROM rust:1-slim AS builder
WORKDIR /app
COPY . .
# Build the application
RUN cargo build --release

# Stage 2: Run
FROM debian:bookworm-slim
# Install minimal runtime dependencies (like SSL for web requests)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Copy the compiled binary from the builder stage
COPY --from=builder /app/target/release/trading-signals-backend .
# Expose the port your app listens on (must match the PORT env variable)
EXPOSE 8080
# Run the binary
CMD ["./trading-signals-backend"]