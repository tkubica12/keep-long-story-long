
# In Linux Terminal 1
export PS1='outer> '
ps aux | grep bash
top
ip a
sudo ls /files

# In Linux Terminal 2
bash
export PS1='process> '
ps aux | grep bash
sudo apt update && sudo apt install stress-ng
stress-ng --cpu 1
ip a
sudo mkdir /files
sudo touch /files/standard.txt

# In Linux Terminal 2
docker run -it --rm --cpus 0.1 ubuntu bash
export PS1='container> '
ps aux | grep bash
apt update && apt install stress-ng iproute2
stress-ng --cpu 1
ip a
mkdir /files
touch /files/container.txt