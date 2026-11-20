{ pkgs, jail, inputs, ... }:
let
  bendRev = "0e2f38f759cc830849e489307f3d256a7d148288";
  bend2 = pkgs.stdenvNoCC.mkDerivation {
    pname = "bend2";
    version = "unstable-${builtins.substring 0 12 bendRev}";
    src = inputs.bend;
    nativeBuildInputs = [ pkgs.bun ];

    buildPhase = ''
      runHook preBuild
      bun build --compile --no-compile-autoload-dotenv --no-compile-autoload-bunfig \
        --outfile bend2-cli bend2/main.ts
      runHook postBuild
    '';

    # Bend finds its runtime assets relative to the executable's bin directory.
    installPhase = ''
      runHook preInstall
      install -Dm755 bend2-cli "$out/bin/bend2"
      ln -s bend2 "$out/bin/bend"
      mkdir -p "$out/bend2"
      cp -r bend2/base.bend bend2/bendtt.lean bend2/effs "$out/bend2/"
      cp -r guide "$out/"
      runHook postInstall
    '';

    # Preserve the Bun executable and its embedded application during fixup.
    dontPatchELF = true;
    dontStrip = true;
  };
in
jail.mkJail {
  inputs.bend = {
    url = "github:bendlang/bend/${bendRev}";
    flake = false;
  };
  sandbox = true;
  packages = with pkgs; [
    uv nodejs rustc cargo rustfmt gnumake cmake clang clang-tools
    zip tree file jujutsu git-lfs fd less bun iverilog yosys bend2
  ];
  network = true;
  nix = true;
  gpu = true;
}
