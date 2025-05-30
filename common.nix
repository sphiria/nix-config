{
  modulesPath,
  lib,
  pkgs,
  nodeSpecs,
  adminSshKey,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 1024;
    "fs.file-max" = 2097152;
    
    "net.core.somaxconn" = 32768;
    "net.core.netdev_max_backlog" = 5000;
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.ipv4.tcp_fin_timeout" = 30;
    "net.ipv4.tcp_keepalive_time" = 120;
    "net.ipv4.tcp_keepalive_probes" = 3;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.ip_local_port_range" = "1024 65535";
    
    # Memory management for containers
    "vm.swappiness" = if nodeSpecs.role == "controlPlane" then 1 else 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "vm.max_map_count" = 262144;
    
    "kernel.pid_max" = 4194304;
    "kernel.threads-max" = if nodeSpecs.role == "controlPlane" then 32768 else 131072;
  };

  powerManagement.cpuFreqGovernor = "performance";
  
  swapDevices = lib.mkForce [ ];
  
  systemd.extraConfig = ''
    DefaultLimitNOFILE=1048576
    DefaultLimitNPROC=${if nodeSpecs.role == "controlPlane" then "32768" else "131072"}
  '';
  
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=${if nodeSpecs.role == "controlPlane" then "1G" else "4G"}
    SystemMaxFileSize=128M
    MaxRetentionSec=7day
    RateLimitInterval=30s
    RateLimitBurst=10000
  '';

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    gitMinimal
    wget
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    adminSshKey
  ];

  # agenix secrets configuration
  age.secrets.k3s-token = {
    file = ./k3s-token.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # hetzner cloud specific networking
  networking = {
    useDHCP = false;
    interfaces = {
      eth0.useDHCP = true;
      enp7s0.useDHCP = true;
    };
    firewall.enable = false;
  };

  # enable container runtime for k3s
  virtualisation.containerd.enable = true;

  system.stateVersion = "24.05";
}