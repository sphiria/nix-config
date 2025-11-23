{ lib, ... }:
{
  disko.devices = {
    disk = {
      nvme0 = {
        device = "/dev/nvme0n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            zfs = {
              name = "zfs";
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
      nvme1 = {
        device = "/dev/nvme1n1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "1G";
              type = "EF00";
            };
            zfs = {
              name = "zfs";
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        mode = "mirror";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };
        options = {
          ashift = "12";
          autotrim = "on";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
            };
          };

          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };

          "var-lib-containerd" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/containerd";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
          };

          "var-lib-rancher" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/rancher";
            options = {
              mountpoint = "legacy";
              recordsize = "16K";
            };
          };

          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
          };

          reserved = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              reservation = "10G";
            };
          };
        };
      };
    };
  };
}
