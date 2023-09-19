# Update and upgrade
sudo apt update && sudo apt upgrade -y

# Install NVIDIA drivers (do not use secure boot for simple installation listed here)
lspci | grep -i NVIDIA   # Check if NVIDIA GPU is present

sudo apt install gcc make -y
wget https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda_12.2.2_535.104.05_linux.run
sudo sh cuda_12.2.2_535.104.05_linux.run

nvidia-smi  # Check if NVIDIA drivers are installed

# Install GUI
sudo apt install ubuntu-desktop -y

# Install XRDP
sudo apt install xrdp -y
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp
sudo systemctl enable xrdp

# Clone repo
git clone https://github.com/tkubica12/keep-long-story-long.git
git config --global user.email "tkubica12@gmail.com"
git config --global user.name "Tomas Kubica"

# Install packages
sudo apt install python3-pip -y

# Install PyTorch and data samples
pip3 install torch torchvision torchtext lightning matplotlib numpy pandas scikit-learn tensorboard torchsummary ultralytics opencv-python tiktoken transformers ipywidgets

# Install Anaconda
curl --output anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2023.07-2-Linux-x86_64.sh
bash anaconda.sh

# Install VSCode
sudo snap install --classic code
code --install-extension ms-toolsai.jupyter
code --install-extension github.copilot
code --install-extension github.vscode-pull-request-github
code --install-extension github.copilot-chat
code --install-extension ms-python.python
code --install-extension dvirtz.parquet-viewer
