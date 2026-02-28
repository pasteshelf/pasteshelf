# Build stage
FROM swift:5.9-jammy AS build
WORKDIR /build

# Copy package manifests first for better caching
COPY Package.swift Package.resolved* ./
RUN swift package resolve

# Copy source code
COPY Sources/ Sources/
COPY Tests/ Tests/

# Build with optimizations
RUN swift build -c release --static-swift-stdlib

# Runtime stage
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    tzdata \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /build/.build/release/App .

# Create non-root user
RUN useradd --create-home appuser
USER appuser

EXPOSE 8080
ENV ENVIRONMENT=production

ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
