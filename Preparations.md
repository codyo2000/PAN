### Installing Docker
1. Set up Docker's `apt` repository.
```bash
sudo apt update && sudo apt upgrade
sudo apt install docker.io docker-compose
```
2. Adding the user to docker group:
```bash
sudo usermod -aG docker $USER
exit

## Sign back in and run `docker ps` to verify ability to run docker commands without sudo
```
3. 