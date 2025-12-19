#!/bin/bash
# Build script for multi-architecture Docker images

set -e

# Default values
IMAGE_NAME="${IMAGE_NAME:-scottcrossen/kube-node-labels}"
VERSION="${VERSION:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Check if buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    echo "Error: docker buildx is not available"
    echo "Please install Docker Buildx or update Docker Desktop"
    exit 1
fi

# Create a new builder instance if it doesn't exist
BUILDER_NAME="multiarch-builder"
if ! docker buildx inspect "$BUILDER_NAME" > /dev/null 2>&1; then
    echo "Creating new buildx builder: $BUILDER_NAME"
    docker buildx create --name "$BUILDER_NAME" --use
else
    echo "Using existing buildx builder: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
fi

# Bootstrap the builder (needed for cross-platform builds)
docker buildx inspect --bootstrap

# Build and push multi-architecture image
echo "Building multi-architecture image: $IMAGE_NAME:$VERSION"
echo "Platforms: $PLATFORMS"

if [ "$PUSH" = "true" ]; then
    echo "Building and pushing to registry..."
    docker buildx build \
        --platform "$PLATFORMS" \
        --tag "$IMAGE_NAME:$VERSION" \
        --push \
        .
    echo "Build and push complete!"
else
    echo "Building locally..."
    echo "Note: --load only supports single platform. Building for native platform."
    echo "For multi-arch builds, use PUSH=true to push to registry, or build individual platforms."
    
    # Detect native platform
    NATIVE_PLATFORM=$(docker buildx inspect --bootstrap | grep "Platforms:" | awk '{print $2}' | cut -d',' -f1)
    if [ -z "$NATIVE_PLATFORM" ]; then
        NATIVE_PLATFORM="linux/amd64"
    fi
    
    echo "Building for platform: $NATIVE_PLATFORM"
    docker buildx build \
        --platform "$NATIVE_PLATFORM" \
        --tag "$IMAGE_NAME:$VERSION" \
        --load \
        .
    echo "Build complete!"
    echo ""
    echo "To build for all platforms and push to registry, run:"
    echo "  PUSH=true ./build.sh"
fi

