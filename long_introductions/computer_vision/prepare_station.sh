# Update and upgrade
sudo apt update && sudo apt upgrade -y

# Install GUI
sudo apt install ubuntu-desktop -y

# Install XRDP
sudo apt install xrdp -y
sudo adduser xrdp ssl-cert
sudo systemctl restart xrdp

# Clone repo
git clone https://github.com/tkubica12/keep-long-story-long.git

# Install VSCode
sudo snap install --classic code