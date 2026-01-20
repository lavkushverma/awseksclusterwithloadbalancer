#!/bin/bash

# 1. Update the system and install 'unzip' (Required to extract the file)
echo "Installing prerequisites..."
sudo yum install unzip -y

# 2. Download the official AWS CLI v2 zip file
echo "Downloading AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# 3. Unzip the file (The -q flag keeps it quiet/clean)
echo "Extracting files..."
unzip -q awscliv2.zip

# 4. Run the installer
# The --update flag allows it to upgrade if an older version exists
echo "Installing AWS CLI..."
sudo ./aws/install --update

# 5. Verify the installation
echo "Installation complete! Checking version:"
aws --version

# 6. Clean up (Delete the zip and folder to save space)
echo "Cleaning up..."
rm -rf awscliv2.zip aws