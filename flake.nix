{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.agenix.url = "github:ryantm/agenix";
  inputs.agenix.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      disko,
      agenix,
      ...
    }:
    {
      nixosConfigurations = 
        let
          inherit (nixpkgs) lib;
          
          clusterName = "sphiria";
          
          keys = import ./keys.nix;
          
          hetznerMachineSpecs = {
            CAX11 = {
              vcpu = 2;
              memory = 4;
              storage = 40;
              reservedCPU = "500m";
              reservedMemory = "1Gi";
              reservedStorage = "10Gi";
            };
            CAX41 = {
              vcpu = 16;
              memory = 32;
              storage = 320;
              reservedCPU = "1000m";
              reservedMemory = "4Gi";
              reservedStorage = "20Gi";
            };
          };
          
          clusterNodes = [
            { name = "ilsa"; role = "controlPlane"; machineType = "CAX11"; privateIP = "10.0.0.2"; }
            { name = "alexiel"; role = "controlPlane"; machineType = "CAX11"; privateIP = "10.0.0.3"; }
            { name = "galleon"; role = "worker"; machineType = "CAX41"; privateIP = "10.0.0.4"; }
            { name = "fediel"; role = "worker"; machineType = "CAX41"; privateIP = "10.0.0.5"; }
          ];
          
          primaryControlPlane = (lib.findFirst (node: node.role == "controlPlane") {} clusterNodes).privateIP;
          
          mkNode = { name, role, machineType, privateIP }: 
            let
              rolePrefix = if role == "controlPlane" then "ctrl" else "work";
              hostname = "${clusterName}-${rolePrefix}-${name}";
              isSecondaryControlPlane = role == "controlPlane" && name != (lib.findFirst (node: node.role == "controlPlane") {} clusterNodes).name;
              nodeSpecs = hetznerMachineSpecs.${machineType} // { inherit role privateIP; };
            in
            nixpkgs.lib.nixosSystem {
              system = "aarch64-linux";
              modules = [
                disko.nixosModules.disko
                agenix.nixosModules.default
                ./common.nix
                (if role == "controlPlane" then ./k3s-ctrl.nix else ./k3s-work.nix)
                {
                  networking.hostName = hostname;
                  _module.args = {
                    primaryControlPlane = primaryControlPlane;
                    nodeSpecs = nodeSpecs;
                    adminSshKey = keys.adminSshKey;
                    isSecondaryControlPlane = isSecondaryControlPlane;
                  };
                }
              ];
            };
            
        in lib.listToAttrs (map (node: { name = node.name; value = mkNode node; }) clusterNodes);
    };
}