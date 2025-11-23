let
  keys = import ./keys.nix;
in
{
  "secrets/k3s-token.age".publicKeys = keys.adminSshKeys ++ keys.systemKeys;
  "secrets/tailscale-auth-key.age".publicKeys = keys.adminSshKeys ++ keys.systemKeys;
  "secrets/ssh-allowed-ips.age".publicKeys = keys.adminSshKeys ++ keys.systemKeys;
  "secrets/restic-password.age".publicKeys = keys.adminSshKeys ++ keys.systemKeys;
  "secrets/restic-env.age".publicKeys = keys.adminSshKeys ++ keys.systemKeys;
  "secrets/restic-repository.age".publicKeys = keys.adminSshKeys ++ keys.systemKeys;
}