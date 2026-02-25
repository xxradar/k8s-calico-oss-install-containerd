sudo echo "systemd.unified_cgroup_hierarchy=1 cgroup_no_v1=all"  | sudo tee -a /etc/default/grub
sudo update-grub
sudo reboot
