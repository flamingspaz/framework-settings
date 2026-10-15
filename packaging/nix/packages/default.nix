{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.2.0";
in
rec {
  framework-kcm = pkgs.callPackage ./framework-kcm.nix { inherit version frameworkd; };
  frameworkd = pkgs.callPackage ./frameworkd.nix { inherit version; };

  default = framework-kcm;
  framework-kcmd = pkgs.lib.warnOnInstantiate "framework-kcmd has been renamed to frameworkd" frameworkd;
}
