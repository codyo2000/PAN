# Steps Before Running Docker Compose
### Installing Docker
1. Set up Docker's `apt` repository.
```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```
2. Install the Docker packages.
```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
3. Verify that the Docker Engine installation is successful by running the `hello-world` image.
```bash
sudo docker run hello-world
```
This command downloads a test image and runs it in a container. When the container runs, it prints a confirmation message and exits.    

You have now successfully installed and started Docker Engine.
### Pi-Hole
1. Modern releases of Ubuntu (17.10+) and Fedora (33+) include `systemd-resolved` which is configured by default to implement a caching DNS stub resolver. This will prevent pi-hole from listening on port 53. The stub resolver should be disabled with: 
```bash
sudo sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
sudo systemctl stop systemd.resolve.service
sudo systemctl disable systemd.resolve.service
```
2. You'll need to add local dns resolution to the `resolve.conf` file:
```bash
sudo nano /etc/resolve.conf

# Add the following line to the file
nameserver 127.0.0.53
```
### Watchtower
For watchtower to work, a docker network named "nginx-proxy" needs to be created:
```bash
docker network create nginx-proxy
```

### Iris
1. Before moving forward, its suggested to modify the environment file to set an admin username/password:
```bash
nano .env
```
2. Uncomment the following lines and change the administrator name if desired. Leave the password the default and change it later from the web GUI, as the password in this file is stored in plain text:
```
#IRIS_ADM_PASSWORD=MySuperAdminPassword!
#IRIS_ADM_EMAIL=admin@localhost
#IRIS_ADM_USERNAME=administrator
```
