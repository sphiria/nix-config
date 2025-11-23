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
    extraFlags = toString ([
      "--tls-san=127.0.0.1"
      "--tls-san=${config.networking.hostName}"
      "--tls-san=sphiria.tail254553.ts.net"
      "--tls-san=100.121.159.119"
      "--disable=traefik"
      "--disable=servicelb"
      "--write-kubeconfig-mode=644"
      "--kubelet-arg=kube-reserved=cpu=${nodeSpecs.reservedCPU},memory=${nodeSpecs.reservedMemory}"
      "--kubelet-arg=system-reserved=cpu=500m,memory=1Gi"
      "--kubelet-arg=eviction-hard=memory.available<2Gi,nodefs.available<10%"
      "--kubelet-arg=max-pods=220"
    ]);
  };

  environment.systemPackages = with pkgs; [
    k3s
    kubectl
  ];
}
