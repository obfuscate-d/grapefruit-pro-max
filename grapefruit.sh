#!/bin/bash

# Grapefruit Master Setup & Run Script
# Single entry point - handles everything automatically

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Banner
echo ""
echo "🍇 =================================="
echo "🍇  Grapefruit Master Setup Script  "
echo "🍇 =================================="
echo ""

# Parse command line arguments
FORCE_REBUILD=false
CHECK_ONLY=false
KILL_EXISTING=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force-rebuild|-f)
            FORCE_REBUILD=true
            shift
            ;;
        --check-only|-c)
            CHECK_ONLY=true
            shift
            ;;
        --kill-existing|-k)
            KILL_EXISTING=true
            shift
            ;;
        --help|-h)
            echo "Grapefruit Master Setup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -f, --force-rebuild    Force rebuild all components"
            echo "  -c, --check-only       Only check setup, don't start server" 
            echo "  -k, --kill-existing    Kill existing server before starting"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Default behavior: Check dependencies, build if needed, then start server"
            exit 0
            ;;
        *)
            print_warning "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if we're in the right directory
if [ ! -f "package.json" ] || ! grep -q "grapefruit\|igf" package.json; then
    print_error "Please run this script from the Grapefruit root directory."
    exit 1
fi

print_status "Found Grapefruit project directory"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system requirements
print_header "🔍 Checking System Requirements..."

# Check Node.js
if command_exists node; then
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | sed 's/v//')
    print_status "Node.js version: $NODE_VERSION"
    
    if [ "$NODE_MAJOR" -lt 16 ] || [ "$NODE_MAJOR" -gt 18 ]; then
        print_warning "Node.js version should be 16.x or 18.x for best compatibility"
        print_info "Current version: $NODE_VERSION - continuing anyway..."
    fi
else
    print_error "Node.js not found! Please install Node.js 18.x LTS first."
    print_info "Visit: https://nodejs.org/"
    exit 1
fi

# Check npm
if command_exists npm; then
    NPM_VERSION=$(npm --version)
    print_status "npm version: $NPM_VERSION"
else
    print_error "npm not found! This should come with Node.js."
    exit 1
fi

# Check Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version)
    print_status "Python version: $PYTHON_VERSION"
else
    print_error "Python 3 not found! Please install Python 3.8+ first."
    exit 1
fi

# Check for Xcode (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "/Applications/Xcode.app" ]; then
        print_status "Xcode application found"
    else
        print_warning "Xcode not found - required for iOS Developer Disk Image"
        print_info "Please install Xcode from the Mac App Store"
    fi
    
    if command_exists xcode-select && xcode-select -p >/dev/null 2>&1; then
        print_status "Xcode Command Line Tools installed"
    else
        print_warning "Xcode Command Line Tools not found"
        print_info "Run: xcode-select --install"
    fi
fi

echo ""

# Python Virtual Environment Setup
print_header "🐍 Setting Up Python Virtual Environment..."

if [ -d ".venv" ]; then
    print_status "Virtual environment already exists"
else
    print_info "Creating Python virtual environment..."
    python3 -m venv .venv
    print_status "Created virtual environment"
fi

# Activate virtual environment
print_info "Activating virtual environment..."
source .venv/bin/activate
print_status "Virtual environment activated"

# Check and install Frida
print_info "Checking Frida installation..."
if command_exists frida; then
    FRIDA_VERSION=$(frida --version 2>/dev/null || echo "unknown")
    print_status "Frida already installed: $FRIDA_VERSION"
else
    print_info "Installing Frida tools..."
    pip install --upgrade pip
    pip install frida-tools
    FRIDA_VERSION=$(frida --version 2>/dev/null || echo "installed")
    print_status "Frida installed: $FRIDA_VERSION"
fi

echo ""

# Node.js Dependencies
print_header "📦 Checking Node.js Dependencies..."

if [ -d "node_modules" ] && [ -f "package-lock.json" ]; then
    print_status "Node.js dependencies already installed"
else
    print_info "Installing Node.js dependencies..."
    npm install
    print_status "Node.js dependencies installed"
fi

echo ""

# Build Server
print_header "🔧 Building Server Component..."

cd server
if [ -d "dist" ] && [ -f "dist/app.js" ] && [ "$FORCE_REBUILD" = false ]; then
    print_status "Server already built"
else
    print_info "Building server..."
    if [ -d "node_modules" ]; then
        print_status "Server dependencies already installed"
    else
        print_info "Installing server dependencies..."
        npm install
    fi
    npm run build
    print_status "Server built successfully"
fi
cd ..

echo ""

# Build GUI
print_header "🎨 Building GUI Component..."

cd gui
if [ -d "dist" ] && [ -f "dist/index.html" ] && [ "$FORCE_REBUILD" = false ]; then
    print_status "GUI already built"
else
    print_info "Building GUI..."
    if [ -d "node_modules" ]; then
        print_status "GUI dependencies already installed"
    else
        print_info "Installing GUI dependencies..."
        npm install
    fi
    
    print_info "Building GUI with Node.js 18+ compatibility..."
    export NODE_OPTIONS="--openssl-legacy-provider"
    npm run build
    print_status "GUI built successfully"
fi
cd ..

echo ""

# Agent Build Check
print_header "🤖 Checking Agent Component..."

if [ -f "agent/dist.js" ]; then
    print_status "Agent already built"
else
    print_info "Building agent..."
    cd agent
    if [ -d "node_modules" ]; then
        print_status "Agent dependencies already installed"
    else
        npm install
    fi
    npm run build
    cd ..
    print_status "Agent built successfully"
fi

echo ""

# Final Setup
print_header "🔧 Final Setup..."

# Make scripts executable
chmod +x start.sh 2>/dev/null || true
chmod +x team-setup.sh 2>/dev/null || true

# Test installation
print_info "Testing Grapefruit installation..."
if timeout 5 node bin/igf --help >/dev/null 2>&1; then
    print_status "Grapefruit CLI working correctly"
else
    print_warning "Grapefruit CLI test had issues, but continuing..."
fi

echo ""

# Device Detection (macOS only)
if [[ "$OSTYPE" == "darwin"* ]] && command_exists idevice_id; then
    print_header "📱 Checking for iOS Devices..."
    DEVICES=$(idevice_id -l 2>/dev/null | head -5 || true)
    if [ -n "$DEVICES" ]; then
        print_status "iOS devices detected:"
        echo "$DEVICES" | while read -r device; do
            if [ -n "$device" ]; then
                DEVICE_NAME=$(ideviceinfo -u "$device" -k DeviceName 2>/dev/null || echo "Unknown Device")
                IOS_VERSION=$(ideviceinfo -u "$device" -k ProductVersion 2>/dev/null || echo "Unknown iOS")
                echo "  📱 $DEVICE_NAME (iOS $IOS_VERSION)"
                echo "     ID: $device"
            fi
        done
    else
        print_warning "No iOS devices detected"
        print_info "Make sure your device is connected via USB and trusted"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    print_warning "libimobiledevice not found - install with: brew install libimobiledevice"
fi

echo ""

# Success message
print_header "🎉 Setup Complete!"
echo ""
echo "Grapefruit is ready to run!"
echo ""

# Exit if check-only mode
if [ "$CHECK_ONLY" = true ]; then
    print_info "Check-only mode: Setup verified, not starting server"
    echo ""
    echo "To start Grapefruit manually:"
    echo "  source .venv/bin/activate"
    echo "  node bin/igf"
    echo ""
    exit 0
fi

# Check if server is already running
if lsof -ti:31337 >/dev/null 2>&1; then
    if [ "$KILL_EXISTING" = true ]; then
        print_info "Killing existing server on port 31337..."
        kill $(lsof -ti:31337) 2>/dev/null || true
        sleep 2
        print_status "Existing server stopped"
    else
        print_warning "Server already running on port 31337!"
        print_info "Options:"
        echo "  1. Kill existing server: ./grapefruit.sh --kill-existing"
        echo "  2. Use different port: node bin/igf --port 31338"
        echo "  3. Open browser: http://localhost:31337"
        exit 1
    fi
fi

echo "🚀 Starting Grapefruit server..."
echo "   Web interface will be available at: http://localhost:31337"
echo "   Press Ctrl+C when you want to stop the server"
echo ""

# Add a small delay for dramatic effect
sleep 1

# Start the server (keeping virtual environment active)
print_info "Launching Grapefruit..."
echo ""

# Final check before starting
if [ ! -f "server/dist/app.js" ]; then
    print_error "Server build not found! Something went wrong during setup."
    exit 1
fi

if [ ! -d "gui/dist" ]; then
    print_error "GUI build not found! Something went wrong during setup."
    exit 1
fi

# Start the server
exec node bin/igf
