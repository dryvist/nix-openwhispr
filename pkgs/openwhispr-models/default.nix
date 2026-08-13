{
  lib,
  stdenvNoCC,
  fetchurl,
  bzip2,
  gnutar,
}:
let
  manifest = builtins.fromJSON (builtins.readFile ../../models.json);
  artifact =
    name:
    let
      spec = manifest.artifacts.${name};
    in
    fetchurl {
      inherit (spec) url sha256;
    };
  segmentationArchive = stdenvNoCC.mkDerivation {
    pname = "openwhispr-speaker-segmentation-model";
    version = manifest.upstreamRelease;
    src = artifact "speakerSegmentation";
    nativeBuildInputs = [
      bzip2
      gnutar
    ];
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/diarization-models"
      tar -xjf "$src" -C "$out/diarization-models"
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "openwhispr-models";
  version = manifest.upstreamRelease;
  dontUnpack = true;
  installPhase = ''
    mkdir -p "$out/diarization-models/sherpa-onnx-pyannote-segmentation-3-0" "$out/embedding-models/all-MiniLM-L6-v2" "$out/whisper-models"
    cp "${segmentationArchive}/diarization-models/sherpa-onnx-pyannote-segmentation-3-0/model.onnx" "$out/diarization-models/sherpa-onnx-pyannote-segmentation-3-0/model.onnx"
    cp "${artifact "speakerEmbedding"}" "$out/diarization-models/3dspeaker_speech_campplus_sv_en_voxceleb_16k.onnx"
    cp "${artifact "sileroVad"}" "$out/diarization-models/silero_vad.onnx"
    cp "${artifact "semanticEmbedding"}" "$out/embedding-models/all-MiniLM-L6-v2/model.onnx"
    cp "${artifact "semanticTokenizer"}" "$out/embedding-models/all-MiniLM-L6-v2/tokenizer.json"
    cp "${artifact "whisperBase"}" "$out/whisper-models/ggml-base.bin"
  '';
  meta = {
    description = "Hash-pinned local speech, speaker, and semantic-search models for OpenWhispr";
    platforms = lib.platforms.darwin;
  };
}
