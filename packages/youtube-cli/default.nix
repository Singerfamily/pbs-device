{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # You also have access to your flake's inputs.
  inputs,

  # The namespace used for your flake, defaulting to "internal" if not set.
  namespace,

  # All other arguments come from NixPkgs. You can use `pkgs` to pull packages or helpers
  # programmatically or you may add the named attributes as arguments here.
  pkgs,
  stdenv,
  ...
}:

with pkgs;
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "google-apis-rs";
  version = "0.106.1";

  src =
    fetchFromGitHub {
      owner = "Byron";
      repo = "google-apis-rs";
      tag = finalAttrs.version;
      hash = "sha256-LM5tDmPWmpHd4HNnWoEdDXdKUkFA8J8VeDFMw32JXLk=";
    }
    + "/gen/youtube3-cli";

  # cargoHash = "sha256-QCkNabv3pqtaRA7Ux5eiZPE/vRILlWKdQce7Gb0vzes=";

  # nativeBuildInputs = [ pkg-config ] ++ lib.optionals stdenv.cc.isClang [ rustPlatform.bindgenHook ];

  # there are no tests
  # doCheck = false;

  # passthru.updateScript = nix-update-script { };

  # meta = {
  #   description = "Nushell plugin for parsing Hashicorp Configuration Language files";
  #   mainProgram = "google-apis-rs";
  #   homepage = "https://github.com/Yethal/nu_plugin_hcl";
  #   license = lib.licenses.mit;
  #   maintainers = with lib.maintainers; [ yethal ];
  # };
})
