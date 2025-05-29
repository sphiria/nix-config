{
  config,
  pkgs,
  lib,
  nodeSpecs,
  ...
}:
{
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.age.secrets.k3s-token.path;
    extraFlags = toString [
      "--cluster-init"
      "--disable=traefik"
      "--disable=servicelb"
      "--flannel-backend=wireguard-native"
      "--write-kubeconfig-mode=644"
      "--node-taint=CriticalAddonsOnly=true:NoExecute"
      "--kubelet-arg=kube-reserved=cpu=${nodeSpecs.reservedCPU},memory=${nodeSpecs.reservedMemory}"
      "--kubelet-arg=system-reserved=cpu=250m,memory=512Mi"
      "--kubelet-arg=eviction-hard=memory.available<500Mi,nodefs.available<10%"
    ];
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
  ];
}