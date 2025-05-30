let
  keys = import ./keys.nix;
  adminKeys = [ keys.adminSshKey ];

  systemKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJdQu8+wYcmcvLU2zpDS6GYFmwsNMUqs88dKanirIFc"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIwJoz8VEhB/gEsv7hzI5hvvdYD8HjnvRJBnjgT8p9TJ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICG8M3j1bp9JVN36Be8bMgWLrH8McqE2QJBAFjtiqzdx"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBG+uCTs6OVXM2v6U/idsdXZKauEb0djoBUbiZcp2IGe"
  ];
in
{
  "k3s-token.age".publicKeys = adminKeys ++ systemKeys;
}