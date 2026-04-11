#!/bin/bash

# 1. Get User Input
read -p "Enter the Linux username you want to use (e.g., devuser): " USERNAME
if [ -z "$USERNAME" ]; then
    USERNAME="devuser"
fi

echo "Creating environment for user: $USERNAME..."

# 2. Create the Dockerfile
cat <<EOF > Dockerfile
FROM ubuntu:22.04

# Setup basic environment
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y sudo ca-certificates

# Create user $USERNAME and add to sudoers
RUN useradd -m -s /bin/bash $USERNAME && \\
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
WORKDIR /work
EOF

# 3. Create the .devcontainer folder
mkdir -p .devcontainer

# 4. Create the devcontainer.json
cat <<EOF > .devcontainer/devcontainer.json
{
    "name": "VeeR-ISS Environment",
    "build": {
        "dockerfile": "../Dockerfile"
    },
    "workspaceFolder": "/work",
    "mounts": [
        {
            "source": "\${localWorkspaceFolder}",
            "target": "/work",
            "type": "bind"
        },
        {
            "source": "veer-system-data",
            "target": "/home/$USERNAME",
            "type": "volume"
        }
    ],
    "remoteUser": "$USERNAME"
}
EOF

echo "------------------------------------------------"
echo " Setup Complete!"
echo "1. Open this folder in VS Code."
echo "2. Click the '><' button in the bottom-left."
echo "3. Select 'Reopen in Container'."
echo "------------------------------------------------"
