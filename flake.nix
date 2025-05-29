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
          
          # Cluster configuration
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
            { name = "ilsa"; role = "controlPlane"; machineType = "CAX11"; }
            { name = "alexiel"; role = "controlPlane"; machineType = "CAX11"; }
            { name = "galleon"; role = "worker"; machineType = "CAX41"; }
            { name = "fediel"; role = "worker"; machineType = "CAX41"; }
          ];
          
          primaryControlPlane = "${clusterName}-ctrl-${(lib.findFirst (node: node.role == "controlPlane") {} clusterNodes).name}";
          
          mkNode = { name, role, machineType }: 
            let
              rolePrefix = if role == "controlPlane" then "ctrl" else "work";
              hostname = "${clusterName}-${rolePrefix}-${name}";
              isSecondaryControlPlane = role == "controlPlane" && name != (lib.findFirst (node: node.role == "controlPlane") {} clusterNodes).name;
              nodeSpecs = hetznerMachineSpecs.${machineType} // { inherit role; };
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
                  };
                }
              ] ++ lib.optionals isSecondaryControlPlane [
                {
                  services.k3s.extraFlags = lib.mkForce (toString [
                    "--server=https://${primaryControlPlane}:6443"
                    "--disable=traefik"
                    "--disable=servicelb"
                    "--flannel-backend=wireguard-native"
                    "--write-kubeconfig-mode=644"
                    "--node-taint=CriticalAddonsOnly=true:NoExecute"
                    "--kubelet-arg=kube-reserved=cpu=${nodeSpecs.reservedCPU},memory=${nodeSpecs.reservedMemory}"
                    "--kubelet-arg=system-reserved=cpu=250m,memory=512Mi"
                    "--kubelet-arg=eviction-hard=memory.available<500Mi,nodefs.available<10%"
                  ]);
                }
              ];
            };
            
        in lib.listToAttrs (map (node: { name = node.name; value = mkNode node; }) clusterNodes);
    };
}
