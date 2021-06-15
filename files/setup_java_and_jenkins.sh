sudo add-apt-repository ppa:openjdk-r/ppa -y > /dev/null 2>&1
sudo apt update > /dev/null 2>&1
sudo apt install openjdk-11-jdk -y > /dev/null 2>&1
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add - > /dev/null 2>&1
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list' > /dev/null 2>&1
sudo apt update > /dev/null 2>&1
sudo apt install jenkins -y > /dev/null 2>&1
sudo service jenkins restart
echo Jenkins Initial Password:
cd /
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo Java and Jenkins ready