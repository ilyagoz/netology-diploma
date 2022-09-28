# -*- mode: ruby -*-
# vi: set ft=ruby :

# For the explanation, refer to https://wiki.debian.org/Avahi and https://github.com/lathiat/nss-mdns
# and https://serverfault.com/questions/268401/configure-zeroconf-to-broadcast-multiple-names
# Removing man-db just to speed things up, db updating takes a lot of time.
$mdns_script = <<-SCRIPT
sudo apt-get update &&
sudo apt-get -y remove man-db && 
sudo apt-get -y remove manpages && 
sudo apt-get -y autoremove && 
sudo apt-get -y install avahi-daemon && 
sudo apt-get -y install avahi-utils &&
echo -e \".local.\n.local\n\" | sudo tee /etc/mdns.allow &&
echo -e \"hosts:          files mdns4_minimal [NOTFOUND=return] dns mdns4\n\" | sudo tee -a /etc/nsswitch.conf > /dev/null
SCRIPT

$avahi_aliases_script = <<-SCRIPT
echo -e \"[Unit]
Description=Publish %I as alias for %H.local via mdns
[Service]
Type=simple
ExecStart=/bin/bash -c \\"/usr/bin/avahi-publish -a -R %I \\$(avahi-resolve -4 -n %H.local | cut -f 2)\\"
[Install]
WantedBy=multi-user.target\" | sudo tee /etc/systemd/system/avahi-alias@.service > /dev/null &&
sudo systemctl enable --now avahi-alias@www.local.service &&
sudo systemctl enable --now avahi-alias@gitlab.local.service &&
sudo systemctl enable --now avahi-alias@grafana.local.service &&
sudo systemctl enable --now avahi-alias@prometheus.local.service &&
sudo systemctl enable --now avahi-alias@alertmanager.local.service
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "512"
    vb.cpus = 2
    vb.linked_clone = true
    vb.check_guest_additions = false
  end
  config.vm.box = "bento/debian-11.4"   

  config.vm.define "nginx" do |nginx|
    nginx.vm.network "private_network", type: "dhcp"
    nginx.vm.hostname = "nginx"
    nginx.vm.provision "shell", inline: $mdns_script
    nginx.vm.provision "shell", inline: $avahi_aliases_script
  end

  config.vm.define "node02" do |node02|
    node02.vm.network "private_network", type: "dhcp"
    node02.vm.hostname = "node02"
    node02.vm.provision "shell", inline: $mdns_script
  end

  config.vm.define "wordpress" do |wordpress|
    wordpress.vm.network "private_network", type: "dhcp"
    wordpress.vm.hostname = "wordpress"
    wordpress.vm.provision "shell", inline: $mdns_script
  end

  config.vm.define "db01" do |db01|
    db01.vm.network "private_network", type: "dhcp"
    db01.vm.hostname = "db01"
    db01.vm.provision "shell", inline: $mdns_script
  end
  config.vm.define "db02" do |db02|
    db02.vm.network "private_network", type: "dhcp"
    db02.vm.hostname = "db02"
    db02.vm.provision "shell", inline: $mdns_script
  end
end
