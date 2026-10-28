{
  config,
  inputs,
  ...
}:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

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
