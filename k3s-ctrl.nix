{
  config,
  pkgs,
  lib,
  nodeSpecs,
  isSecondaryControlPlane ? false,
  primaryControlPlane ? "",
  ...
}:
{
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.age.secrets.k3s-token.path;
    extraFlags = toString ([
      (if isSecondaryControlPlane 
       then "--server=https://${primaryControlPlane}:6443" 
       else "--cluster-init")
      "--tls-san=127.0.0.1"
      "--tls-san=${nodeSpecs.privateIP}"
      "--tls-san=${config.networking.hostName}"
      "--disable=traefik"
      "--disable=servicelb"
      "--flannel-backend=wireguard-native"
      "--write-kubeconfig-mode=644"
      "--node-taint=CriticalAddonsOnly=true:NoExecute"
      "--node-ip=${nodeSpecs.privateIP}"
      "--kubelet-arg=kube-reserved=cpu=${nodeSpecs.reservedCPU},memory=${nodeSpecs.reservedMemory}"
      "--kubelet-arg=system-reserved=cpu=250m,memory=512Mi"
      "--kubelet-arg=eviction-hard=memory.available<500Mi,nodefs.available<10%"
    ]);
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
  ];
}