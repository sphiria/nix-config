{
  config,
  modulesPath,
  lib,
  pkgs,
  nodeSpecs,
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
    
    # memory management for containers
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "vm.max_map_count" = 262144;

    "kernel.pid_max" = 4194304;
    "kernel.threads-max" = 131072;
  };

  powerManagement.cpuFreqGovernor = "performance";
  
  swapDevices = lib.mkForce [ ];
  
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  systemd.extraConfig = ''
    DefaultLimitNOFILE=1048576
    DefaultLimitNPROC=131072
  '';
  
  services.journald.extraConfig = ''
    Storage=persistent
    Compress=yes
    SystemMaxUse=4G
    SystemMaxFileSize=128M
    MaxRetentionSec=7day
    RateLimitInterval=30s
    RateLimitBurst=10000
  '';

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
  };

  environment.systemPackages = with pkgs; [
    curl
    gitMinimal
    wget
  ];

  users.users.root.openssh.authorizedKeys.keys =
    let keys = import ./keys.nix;
    in keys.adminSshKeys;

  # agenix secrets configuration
  age.secrets.k3s-token = {
    file = ./secrets/k3s-token.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  age.secrets.tailscale-auth-key = {
    file = ./secrets/tailscale-auth-key.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  age.secrets.ssh-allowed-ips = {
    file = ./secrets/ssh-allowed-ips.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  age.secrets.restic-password = {
    file = ./secrets/restic-password.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  age.secrets.restic-env = {
    file = ./secrets/restic-env.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  age.secrets.restic-repository = {
    file = ./secrets/restic-repository.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # networking configuration
  networking = {
    useDHCP = false;
    interfaces.eth0.useDHCP = true;

    firewall = {
      enable = true;

      allowedTCPPorts = [ 80 443 ];

      # allow k3s internal networking and tailscale
      trustedInterfaces = [ "cni0" "flannel.1" "tailscale0" ];

      extraCommands = ''
        # k3s/ssh tailscale
        iptables -A nixos-fw -s 100.64.0.0/10 -p tcp --dport 6443 -j nixos-fw-accept
        iptables -A nixos-fw -s 100.64.0.0/10 -p tcp --dport 22 -j nixos-fw-accept

        # whitelist
        if [ -f ${config.age.secrets.ssh-allowed-ips.path} ]; then
          while IFS= read -r ip; do
            [[ -z "$ip" || "$ip" =~ ^# ]] && continue
            iptables -A nixos-fw -s "$ip" -p tcp --dport 22 -j nixos-fw-accept
            iptables -A nixos-fw -s "$ip" -p tcp --dport 6443 -j nixos-fw-accept
          done < ${config.age.secrets.ssh-allowed-ips.path}
        fi
      '';
    };
  };

  # enable container runtime for k3s
  virtualisation.containerd.enable = true;

  # ZFS configuration
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "8425e349";  # Required for ZFS (random 8-char hex)

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    trim = {
      enable = true;
      interval = "weekly";
    };
  };

  # ZFS ARC tuning (limit to 16GB on 64GB system, leaving plenty for k8s)
  boot.kernelParams = [ "zfs.zfs_arc_max=17179869184" ];  # 16GB in bytes

  # ZFS automatic snapshots
  services.sanoid = {
    enable = true;
    datasets."rpool/root" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 7;
      monthly = 3;
    };
    datasets."rpool/home" = {
      autosnap = true;
      autoprune = true;
      hourly = 24;
      daily = 7;
      monthly = 6;
    };
    datasets."rpool/var-lib-rancher" = {
      autosnap = true;
      autoprune = true;
      hourly = 12;
      daily = 3;
      monthly = 0;
    };
  };

  # backups
  services.restic.backups = {
    daily = {
      initialize = true;
      passwordFile = config.age.secrets.restic-password.path;
      environmentFile = config.age.secrets.restic-env.path;
      repositoryFile = config.age.secrets.restic-repository.path;

      paths = [
        "/var/lib/rancher"
      ];

      exclude = [
        "/var/lib/rancher/k3s/storage"
        "/var/lib/rancher/k3s/agent/containerd"
      ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
        "--keep-yearly 2"
      ];
    };
  };

  system.stateVersion = "25.05";
}