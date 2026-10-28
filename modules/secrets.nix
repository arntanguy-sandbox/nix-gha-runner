{
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  services.sshd.enable = true;

  microvm.shares = [
    {
      proto = "9p";
      tag = "ssh";
      source = config.services.nixGhaRunner.ageKeyDirectory;
      mountPoint = "/etc/age";
    }
  ];

  fileSystems."/etc/age".neededForBoot = true;

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = "/etc/age/keys.txt";
  };
}
