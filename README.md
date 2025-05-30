# sphiria k3s cluster on hetzner cloud

### control plane nodes (CAX11: 2vCPU, 4GB RAM, 40GB SSD)
- `sphiria-ctrl-ilsa` - primary control plane node
- `sphiria-ctrl-alexiel` - secondary control plane node

### worker nodes (CAX41: 16vCPU, 32GB RAM, 320GB SSD)
- `sphiria-work-galleon` - worker node
- `sphiria-work-fediel` - worker node

## configuration

### 1. update ssh keys

Update your SSH public key in `keys.nix` (single source of truth):

```nix
{
  adminSshKey = "ssh-ed25519 YOUR_PUBLIC_KEY_HERE";
}
```

### 2. setup agenix and encrypt the k3s token

This project uses [agenix](https://github.com/ryantm/agenix) for secret management. 

generate and encrypt the k3s token:

```bash
# generate a secure token
openssl rand -hex 32 > /tmp/k3s-token

# encrypt it with agenix
nix run github:ryantm/agenix -- -e k3s-token.age -i ~/.ssh/key

# clean up the plaintext token
rm /tmp/k3s-token
```

this creates an encrypted `k3s-token.age` file that can be safely committed to git.

## deployment


### 1. deploy primary control plane

```bash
nix run github:nix-community/nixos-anywhere -- -i ~/.ssh/key --flake .#ilsa --target-host ilsa
```

### 2. deploy secondary control plane

```bash
nix run github:nix-community/nixos-anywhere -- -i ~/.ssh/key --flake .#alexiel --target-host alexiel
```

### 3. deploy worker nodes

```bash
nix run github:nix-community/nixos-anywhere -- -i ~/.ssh/key --flake .#galleon --target-host galleon
nix run github:nix-community/nixos-anywhere -- -i ~/.ssh/key --flake .#fediel --target-host fediel
```

### 4. update ssh host keys (post-deploy)

after all nodes are deployed, add their ssh host keys to `secrets.nix` for proper secret decryption on future deployments:

```bash
ssh-keyscan -t ed25519 <ilsa-ip>
ssh-keyscan -t ed25519 <alexiel-ip>
ssh-keyscan -t ed25519 <galleon-ip>
ssh-keyscan -t ed25519 <fediel-ip>

# add the public key parts to systemKeys array in secrets.nix
```

then re-encrypt the secret:

```bash
agenix -r
```

## updating existing nodes

after initial deployment, use `nixos-rebuild` to update configurations:

### update all nodes

```bash
# update control plane nodes
nixos-rebuild switch --flake .#ilsa --target-host ilsa --use-remote-sudo
nixos-rebuild switch --flake .#alexiel --target-host alexiel --use-remote-sudo

# update worker nodes  
nixos-rebuild switch --flake .#galleon --target-host galleon --use-remote-sudo
nixos-rebuild switch --flake .#fediel --target-host fediel --use-remote-sudo
```

### update single node

```bash
nixos-rebuild switch --flake .#<node-name> --target-host root@<node-ip> --use-remote-sudo
```

### test configuration without switching

```bash
nixos-rebuild test --flake .#<node-name> --target-host root@<node-ip> --use-remote-sudo
```

### build configuration locally first

```bash
nixos-rebuild build --flake .#<node-name>
```

### kubectl
```bash
ssh -L 127.0.0.1:6443:10.0.0.2:6443 ilsa -N
kubectl get pods
```