{ self, inputs, ... }: {
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # To generate host keys (which appear to remain static)
  services.sshd.enable = true;

  microvm.shares = [
    {
      proto = "9p";
      tag = "ssh";
      source = "/home/arnaud/.config/sops/age"; # FIXME: make configurable
      mountPoint = "/etc/age";
    }
  ];

  fileSystems."/etc/age".neededForBoot = true;

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/etc/age/keys.txt";
    secrets = {
      isri-aist-github_token = {
        key = "data/isri-aist/github_token";
        mode = "0400";
        owner = "root";
      };
      arntanguy-sandbox-github_token = {
        key = "data/arntanguy-sandbox/github_token";
        mode = "0400";
        owner = "root";
      };
    };
  };
}
