let
  keys = import ./keys.nix;
  adminKeys = [ keys.adminSshKey ];

  systemKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJdQu8+wYcmcvLU2zpDS6GYFmwsNMUqs88dKanirIFc"
  ];
in
{
  "k3s-token.age".publicKeys = adminKeys ++ systemKeys;
}