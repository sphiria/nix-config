{
  config,
  pkgs,
  lib,
  primaryControlPlane,
  nodeSpecs,
  ...
}:
{
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://${primaryControlPlane}:6443";
    tokenFile = config.age.secrets.k3s-token.path;
    extraFlags = toString [
      "--node-ip=${nodeSpecs.privateIP}"
      "--kubelet-arg=kube-reserved=cpu=${nodeSpecs.reservedCPU},memory=${nodeSpecs.reservedMemory}"
      "--kubelet-arg=system-reserved=cpu=500m,memory=1Gi"
      "--kubelet-arg=eviction-hard=memory.available<2Gi,nodefs.available<10%"
      "--kubelet-arg=max-pods=220"
    ];
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
  ];
}