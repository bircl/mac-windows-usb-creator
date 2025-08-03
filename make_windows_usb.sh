#!/bin/bash

# This script automates the process of creating a bootable Windows USB drive on macOS.
# It handles splitting the install.wim file if it's larger than 4GB, which is
# necessary for FAT32 formatted USB drives.

# --- Configuration ---
# Set to 'true' for debug messages, 'false' to suppress them.
DEBUG_MODE=false

# --- Functions ---

# Function to display debug messages
debug_log() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "[DEBUG] $1"
    fi
}

# Function to check for required commands
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: '$1' is not installed or not in your PATH."
        echo "Please install it. For 'wimlib-imagex', you can use Homebrew:"
        echo "  brew install wimlib"
        exit 1
    fi
}

# Function to prompt for confirmation
confirm_action() {
    read -p "$1 (y/N): " -n 1 -r
    echo # Move to a new line
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
}

# --- Main Script ---

echo "--- Bootable Windows USB Creator for macOS ---"
echo "This script will guide you through creating a bootable Windows USB drive."
echo "------------------------------------------------"

# 1. Check for prerequisites
echo "Checking for required tools..."
check_command "hdiutil"
check_command "diskutil"
check_command "rsync"
check_command "stat" # Used to get file size
check_command "wimlib-imagex"
echo "All required tools found."

# 2. Get Windows ISO path from user
echo ""
read -p "Enter the full path to your Windows ISO file (e.g., /Users/youruser/Downloads/Win11.iso): " ISO_PATH

# Validate ISO path
if [[ ! -f "$ISO_PATH" ]]; then
    echo "Error: ISO file not found at '$ISO_PATH'."
    exit 1
fi
debug_log "ISO Path: $ISO_PATH"

# 3. List disks and get USB device identifier from user
echo ""
echo "--- Identifying your USB Drive ---"
echo "Please connect your USB drive now if you haven't already."
echo "Listing all connected disks. Carefully identify your USB drive:"
echo "------------------------------------------------"
diskutil list
echo "------------------------------------------------"

echo -e "\n!!! WARNING: All data on the selected disk will be PERMANENTLY ERASED !!!"
echo "Make absolutely sure you select the correct disk, not your main hard drive."
echo "Look for the 'IDENTIFIER' (e.g., 'disk2', 'disk3')."

confirm_action "Do you understand the risk and wish to proceed?"

read -p "Enter the disk identifier for your USB drive (e.g., disk2, NOT /dev/disk2s1): " USB_DISK_IDENTIFIER

# Validate USB disk identifier format (basic check)
if [[ ! "$USB_DISK_IDENTIFIER" =~ ^disk[0-9]+$ ]]; then
    echo "Error: Invalid disk identifier format. Please enter something like 'disk2'."
    exit 1
fi
debug_log "USB Disk Identifier: /dev/$USB_DISK_IDENTIFIER"

confirm_action "Are you absolutely sure you want to erase and format /dev/$USB_DISK_IDENTIFIER?"

# 4. Mount the Windows ISO
echo ""
echo "Mounting Windows ISO..."
# hdiutil attach outputs lines, the last one usually contains the mount point
ISO_MOUNT_POINT=$(hdiutil attach -nobrowse "$ISO_PATH" | tail -n 1 | awk '{$1=$1;print}')
if [ -z "$ISO_MOUNT_POINT" ]; then
    echo "Error: Failed to mount ISO file."
    exit 1
fi
debug_log "ISO Mounted at: $ISO_MOUNT_POINT"
echo "ISO mounted successfully."

# 5. Erase and format the USB drive
echo ""
echo "Erasing and formatting USB drive '/dev/$USB_DISK_IDENTIFIER' to FAT32..."
# Use MBR (Master Boot Record) for compatibility with older BIOS systems
diskutil eraseDisk FAT32 "WININSTALL" MBR "/dev/$USB_DISK_IDENTIFIER"
if [ $? -ne 0 ]; then
    echo "Error: Failed to erase and format USB drive."
    hdiutil detach "$ISO_MOUNT_POINT" # Clean up mounted ISO
    exit 1
fi
USB_DEST_PATH="/Volumes/WININSTALL"
debug_log "USB formatted and mounted at: $USB_DEST_PATH"
echo "USB drive formatted successfully."

# 6. Copy all files from ISO to USB, excluding install.wim (if present)
echo ""
echo "Copying all files from ISO to USB (excluding 'sources/install.wim')..."
# The trailing slash on "$ISO_MOUNT_POINT"/ is crucial for rsync to copy contents, not the directory itself.
rsync -av --exclude="sources/install.wim" "$ISO_MOUNT_POINT"/ "$USB_DEST_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy initial files from ISO to USB."
    hdiutil detach "$ISO_MOUNT_POINT"
    exit 1
fi
echo "Initial files copied."

# 7. Handle install.wim / install.swm splitting
INSTALL_WIM_SOURCE_PATH="$ISO_MOUNT_POINT/sources/install.wim"
INSTALL_WIM_DEST_DIR="$USB_DEST_PATH/sources"

if [[ -f "$INSTALL_WIM_SOURCE_PATH" ]]; then
    echo ""
    echo "Checking size of install.wim..."
    # Get file size in bytes
    INSTALL_WIM_SIZE_BYTES=$(stat -f%z "$INSTALL_WIM_SOURCE_PATH")
    debug_log "install.wim size: $INSTALL_WIM_SIZE_BYTES bytes"

    # FAT32 max file size is 4GB (4,294,967,295 bytes). We'll use a slightly smaller threshold for safety.
    MAX_FAT32_FILE_SIZE=$((4 * 1024 * 1024 * 1024 - 1000000)) # Approx 3.999 GB

    if (( INSTALL_WIM_SIZE_BYTES > MAX_FAT32_FILE_SIZE )); then
        echo "install.wim is larger than 4GB. Splitting it into .swm files..."
        mkdir -p "$INSTALL_WIM_DEST_DIR" # Ensure sources directory exists on USB
        # Split into 4000 MB (approx 4GB) parts
        wimlib-imagex split "$INSTALL_WIM_SOURCE_PATH" "$INSTALL_WIM_DEST_DIR/install.swm" 4000
        if [ $? -ne 0 ]; then
            echo "Error: Failed to split install.wim."
            hdiutil detach "$ISO_MOUNT_POINT"
            exit 1
        fi
        echo "install.wim successfully split and copied as install.swm files."
    else
        echo "install.wim is 4GB or less. Copying directly..."
        cp "$INSTALL_WIM_SOURCE_PATH" "$INSTALL_WIM_DEST_DIR/"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to copy install.wim."
            hdiutil detach "$ISO_MOUNT_POINT"
            exit 1
        fi
        echo "install.wim copied successfully."
    fi
else
    echo "Warning: install.wim not found in ISO's sources directory. Skipping wim handling."
fi

# 8. Clean up: Unmount ISO
echo ""
echo "Unmounting Windows ISO..."
hdiutil detach "$ISO_MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "Warning: Failed to unmount ISO. You may need to unmount it manually."
fi

echo ""
echo "------------------------------------------------"
echo "Bootable Windows USB creation complete!"
echo "You can now safely eject your USB drive from Finder."
echo "------------------------------------------------"