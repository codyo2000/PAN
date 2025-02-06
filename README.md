<p align="center">
<img src="PAN.png" alt="drawing" width="420"/>
</p>

## Welcome to PAN - the Preconfigured Application Node!
Think of it as a **cybersecurity Swiss Army knife**, but in **Docker form**.  
One container to rule them all, deploy them all, and defend them all.  

### 🚀 Why PAN?  
- 🔧 Because setting up security tools manually is too much hassle.  
- 🔍 Because you'd rather focus on security, not troubleshooting dependencies.
- 🐳 Because Docker makes everything easier (most of the time).  

### 🛠 Getting Started  
1. Clone the repository  
   ```sh
   git clone https://github.com/codyo2000/pan.git
   cd pan
   ```
2. Before continuing, download an updated copy of the hunt handbook(HH) and mkdocs config file, and put it in `./data/mkdocs`. The HH should come with a directory named `docs` and a file named `mkdocs.yml`
3. Make the install script executable
   ```sh
   chmod +x install_pan.sh
   ```
4. Run the install script with your base domain as an option
   ```sh
   ./install_pan.sh -d <BASE_DOMAIN>
   ```
5. Once the script runs, point your PC to the IP address of PAN for DNS, and go to `https://pan.<BASE_DOMAIN>` to reach the landing page
6. On the landing page, click on `CA Certificate` then copy and paste this to a text file. Save it as `ca.crt` and upload it to your browser's trusted CAs in settings
7. Success! You now have a glorious instance of PAN ready and are one step closer to defeating your enemies in cyberspace...

**IMPORTANT NOTE:** PAN is designed to run on Ubuntu Server v22.0.4 LTS