# Whisper model catalogue

MAPL supports the multilingual Tiny and Base models used by the subtitle generator. Downloads and hashes are pinned to the upstream `ggerganov/whisper.cpp` model repository at revision `5359861c739e955e79d9a303bcbc70fb988958b1`.

| Model | Bytes | SHA-256 |
| --- | ---: | --- |
| Tiny | 77,691,713 | `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21` |
| Base | 147,951,465 | `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe` |

These values were checked against the official Git LFS pointers for [Tiny](https://huggingface.co/ggerganov/whisper.cpp/raw/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.bin) and [Base](https://huggingface.co/ggerganov/whisper.cpp/raw/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin). The LFS `oid sha256` identifies the actual model content, not the pointer text. Sizes are displayed in decimal MB.

To update the catalogue, choose an upstream revision, inspect its official LFS pointers, and update the revision, sizes and SHA-256 values together in `src/ModelDownloader.cpp` and this document. Do not obtain expected checksums from the response being verified or silently accept a changed upstream file.

## Installation and verification

The **Whisper models** sidebar button opens the model manager. It shows expected and on-disk sizes, installed/invalid/verifying/downloading states, errors, and download, cancellation and deletion controls. Opening it verifies existing models in a cancellable background thread. Model preparation also rehashes existing files before each transcription, regardless of cached display status. A corrupt or incomplete model is replaced by a verified download when generation requests it.

Downloads stream through SHA-256 into [`QSaveFile`](https://doc.qt.io/qt-6/qsavefile.html), with direct-write fallback disabled. The final filename is published with `commit()` only after a successful HTTP response, exact byte count and matching checksum. Cancellation, shutdown, short writes, checksum mismatches and commit failures discard the staged data and preserve any previous destination file.

Models stay in `$XDG_CACHE_HOME/mapl-player` (normally `~/.cache/mapl-player`), including models downloaded by earlier MAPL versions. Legacy files are unverified until their checksums pass. Deletion and replacement are blocked while the model is in use by a Whisper worker, including cancellation cleanup. Closing the manager leaves a download running; its Cancel control stops it.
