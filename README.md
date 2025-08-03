# Bootable Windows USB Creator for macOS

This script automates the process of creating a bootable Windows USB drive on macOS. It's particularly useful for Windows ISOs where the `install.wim` file is larger than 4GB, as it handles splitting this file for FAT32 formatted USB drives.

## Features

* Automates disk formatting (FAT32 with MBR).
* Copies all necessary files from a Windows ISO to your USB.
* Automatically splits `install.wim` into `.swm` files if it exceeds the 4GB FAT32 file size limit, using `wimlib-imagex`.
* Provides clear prompts and warnings.

## Prerequisites

Before running this script, ensure you have the following installed:

1.  **Homebrew:** If you don't have Homebrew, install it by running this command in your Terminal:
    ```bash
    /bin/bash -c "$(curl -fsSL [https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh](https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh))"
    ```
2.  **`wimlib`:** Install `wimlib` (which includes `wimlib-imagex`) using Homebrew:
    ```bash
    brew install wimlib
    ```

## How to Use

1.  **Download the script:**
    * Go to the `make_windows_usb.sh` file in this repository.
    * Click the "Raw" button.
    * Right-click on the page and select "Save As..." to save the script to your computer (e.g., in your Downloads folder).

2.  **Make the script executable:**
    Open your Terminal application, navigate to where you saved the script, and run:
    ```bash
    chmod +x make_windows_usb.sh
    ```

3.  **Run the script:**
    ```bash
    ./make_windows_usb.sh
    ```

4.  **Follow the prompts:**
    * You will be asked for the full path to your Windows ISO file.
    * The script will list your connected disks. **Carefully identify your USB drive's identifier (e.g., `disk2`, `disk3`). Selecting the wrong disk will result in data loss!**
    * Confirmations will be requested before proceeding with formatting.

## Important Warnings

* **ALL DATA ON THE SELECTED USB DRIVE WILL BE PERMANENTLY ERASED.** Double-check your disk selection.
* Ensure your Windows ISO is valid and accessible.

---
**Disclaimer:** Use this script at your own risk. The author is not responsible for any data loss or damage.