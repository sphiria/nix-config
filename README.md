# sphiria k3s

## configuration

### 1. update ssh keys

```nix
{
  adminSshKey = "ssh-ed25519 YOUR_PUBLIC_KEY_HERE";
}
```

### 2. setup agenix and encrypt the k3s token

generate and encrypt the k3s token:

```bash
# generate a secure token
openssl rand -hex 32 > /tmp/k3s-token

# encrypt it with agenix
nix run github:ryantm/agenix -- -e k3s-token.age -i ~/.ssh/key < /tmp/k3s-token

# clean up the plaintext token
rm /tmp/k3s-token
```

this creates an encrypted `k3s-token.age` file that can be safely committed to git.

## deployment

### 1. deploy

```bash
nix run github:nix-community/nixos-anywhere -- -i ~/.ssh/key --flake .#sphiria --target-host sphiria
```

### 4. update ssh host keys (post-deploy)

after all nodes are deployed, add their ssh host keys to `secrets.nix` for proper secret decryption on future deployments:

```bash
ssh-keyscan -t ed25519 sphiria
```

then rekey everything:

```bash
nix run github:ryantm/agenix -- --rekey -i ~/.ssh/key
```

## updating existing nodes

after initial deployment, use `nixos-rebuild` to update configurations:

```bash
# update
nix run nixpkgs#nixos-rebuild -- switch --flake .#sphiria --target-host sphiria --use-remote-sudo
```

### test configuration without switching

```bash
nix run nixpkgs#nixos-rebuild -- test --flake .#sphiria --target-host sphiria --use-remote-sudo
```

### build configuration locally first

```bash
nix run nixpkgs#nixos-rebuild -- build --flake .#sphiria
```
