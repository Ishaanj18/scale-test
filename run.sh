#!/bin/bash

# Simple script to build and run single Android emulator

echo "=== Android Emulator Test Setup ==="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed"  
    exit 1
fi

# Function to start the container
start() {
    echo "Building Docker image..."
    docker-compose build
    
    echo "Starting Android emulator container..."
    docker-compose up -d
    
    echo "Waiting for container to start..."
    sleep 15
    
    echo ""
    echo "=== Container Started ==="
    echo "📱 Web VNC Access: http://localhost:6080"
    echo "🖥️  VNC Client: localhost:5900"
    echo "📱 ADB Connect: adb connect localhost:5555"
    echo ""
    echo "📋 Useful commands:"
    echo "   docker-compose logs -f    # View logs"
    echo "   docker-compose exec android-emulator bash  # Shell access"
    echo "   docker-compose down      # Stop container"
    echo ""
    echo "⏳ Android emulator may take 2-3 minutes to fully boot"
    echo "   Check progress at: http://localhost:6080"
}

# Function to stop the container  
stop() {
    echo "Stopping container..."
    docker-compose down
    echo "✓ Container stopped"
}

# Function to show logs
logs() {
    docker-compose logs -f
}

# Function to show status
status() {
    docker-compose ps
    echo ""
    echo "Container logs (last 10 lines):"
    docker-compose logs --tail=10
}

# Function to connect via ADB
adb_connect() {
    echo "Connecting to Android emulator via ADB..."
    adb connect localhost:5555
    echo ""
    echo "Available ADB commands:"
    echo "  adb devices                    # List connected devices"
    echo "  adb shell                      # Open shell in emulator"
    echo "  adb install app.apk           # Install APK"
    echo "  adb shell am start -n com.package.name/.MainActivity  # Start app"
}

# Function to restart
restart() {
    stop
    sleep 2
    start
}

# Main command handling
case "${1:-start}" in
    "start")
        start
        ;;
    "stop")
        stop
        ;;
    "restart")
        restart
        ;;
    "logs")
        logs
        ;;
    "status")
        status
        ;;
    "adb")
        adb_connect
        ;;
    "shell")
        docker-compose exec android-emulator bash
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|adb|shell}"
        echo ""
        echo "Commands:"
        echo "  start   - Build and start the Android emulator"
        echo "  stop    - Stop the container"
        echo "  restart - Restart the container"
        echo "  logs    - Show container logs"
        echo "  status  - Show container status"
        echo "  adb     - Connect via ADB"
        echo "  shell   - Open shell in container"
        exit 1
        ;;
esac