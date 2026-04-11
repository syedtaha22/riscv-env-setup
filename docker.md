# MacOS Linux Development Environment Guide

This guide explains how to set up a persistent Linux development environment on your Mac using Docker and VS Code. This setup allows you to run Linux-specific tools (like the VeeR-ISS simulator or RISC-V compilers) while keeping your code safe on your Mac.

## 1. How the Setup Works

The setup uses three main components to bridge the gap between your Mac and Linux:

### A. The Dockerfile

```Dockerfile
FROM ubuntu:22.04

# Setup basic environment
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y sudo ca-certificates

# Create a generic user so they don't have permission issues
RUN useradd -m -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER devuser
WORKDIR /work
```


This is the "blueprint" for your Linux machine. It tells Docker to:
* Use **Ubuntu 22.04** as the base.
* Create a **custom user** (so you don't have file permission issues).
* Give that user **sudo** powers so you can install packages (like `boost` or `gcc-11`) just like a real Linux computer.

### B. The .devcontainer/devcontainer.json

```json
{
    "name": "VeeR-ISS Environment",
    "build": {
        "dockerfile": "../Dockerfile"
    },
    "workspaceFolder": "/work",
    "mounts": [
        "source=${localWorkspaceFolder},target=/work,type=bind",
        "source=veer-system-data,target=/home/devuser,type=volume"
    ],
    "remoteUser": "devuser"
}
```

This tells VS Code how to interact with Docker:
* **Mounting (/work):** It links your current Mac project folder to a folder inside Linux called `/work`. Any code change you make on your Mac is instantly updated in Linux.
* **Persistence (Volume):** It creates a "virtual hard drive" called `veer-system-data`. This stores your Linux home directory, history, and settings so they don't disappear when you close the container.

### C. VS Code `Dev Containers` Extension

This extension allows you to open/reopen your current folder inside a docker container. It handles all the behind-the-scenes work of building the container from the Dockerfile, mounting your project folder, and connecting your terminal and debugger to the Linux environment. So you don't need to run tedious `docker build` or `docker run` commands manually. Just click "Reopen in Container" and it does everything for you.

---

## 2. Using the Setup Script

To automate the creation of these files, use the `setup_env.sh` script.

### Step 1: Prepare the Script
1. Place `setup_env.sh` in your project folder.
2. Open your Mac terminal and navigate to your project folder.
3. Make the script executable:
   ```bash
   chmod +x setup_env.sh
   ```

### Step 2: Run the Script
1. Execute the script:
   ```bash
   ./setup_env.sh
   ```
2. Enter your desired Linux username when prompted (e.g., `tim` or `developer`).
3. The script will automatically create the `Dockerfile` and the `.devcontainer` folder.

---

## 3. Launching the Environment

1. Open your project folder in **Visual Studio Code**.
2. Look for a notification in the bottom-right corner saying "Folder contains a Dev Container configuration file."
3. Click **Reopen in Container**. 
   * *Alternatively: Click the green `><` button in the bottom-left corner and select "Reopen in Container".*
4. Wait for the first-time setup. Once complete, you will see `Dev Container: VeeR-ISS Environment` in the bottom-left corner.

---

## 4. Helpful Tips for Beginners

* **Installing Tools:** Once the terminal is open, you can install anything you need using `sudo apt install <package-name>`. These will stay installed forever thanks to the persistent volume.
* **Where are my files?** Your project files are always in `/work`.
* **Starting Over:** If you want a completely "Factory Reset" environment:
  1. Open your Mac terminal.
  2. Run `docker rm -f ecstatic_bhabha` (or your specific container name).
  3. Run `docker volume rm veer-system-data`.
  4. Re-open in VS Code.
* **Performance:** Ensure **Docker Desktop** is running on your Mac before opening VS Code.
