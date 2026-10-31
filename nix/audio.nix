{ lib
, stdenv
, fetchFromGitHub
, pkg-config
, pipewire
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "serpantinum-audio";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "ilyamiro";
    repo = "serpantinum-audio";
    rev = "v${finalAttrs.version}";
    hash = "sha256-0b2ja2xtcedhfMxdyFd+S5me3IGRtDJsS5bR3nOi4/I=";
  };

  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ pipewire ];

  doCheck = true;
  checkTarget = "test";

  makeFlags = [ "PREFIX=$(out)" ];

  meta = {
    description = "PipeWire audio processor for the Serpantinum shell";
    homepage = "https://github.com/ilyamiro/serpantinum-audio";
    license = lib.licenses.agpl3Only;
    mainProgram = "serpantinum-audio";
    platforms = lib.platforms.linux;
  };
})
