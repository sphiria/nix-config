{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
          nodeSpecs = {
            vcpu = 16;
            memory = 64;
            storage = 512;
            reservedCPU = "1000m";
            reservedMemory = "4Gi";
            reservedStorage = "20Gi";
          };
        in {
          sphiria = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              disko.nixosModules.disko
              agenix.nixosModules.default
              ./common.nix
              ./k3s.nix
              {
                networking.hostName = clusterName;
                _module.args = {
                  nodeSpecs = nodeSpecs;
                };
              }
            ];
          };
        };
    };
}