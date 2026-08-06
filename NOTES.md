# otterOS NOTES

- 2026-08-06: bing serves real HTML only to curl UAs; expat broken in brew python (regex-parse XML). ASC cert cap = revoke Created-via-API dev certs (DELETE /v1/certificates). exportArchive "Error Downloading App Information" = missing ASC app record — POST /v1/apps is 403, create in UI.
- iOS cannot record cellular call audio (any version, incl. 26) — mic+speakerphone is the Otter pattern; REC indicator required (guideline 2.5.14).
- SpeechTranscriber (iOS 26): locale must come from supportedLocales (bcp47); finalizeAndFinishThroughEndOfInput() on stop or the volatile tail is lost; convert engine buffers to bestAvailableAudioFormat.
- 2026-08-06 (v2): auto-version hook's amended force-push comes from a bot token → push events do NOT trigger CI; always `gh workflow run CI --ref main` after pushing. Mac clock was 38.5h behind (staged-update fallout) → every locally-minted ASC JWT "expired"; fix clock first, then mint. Recorder "Failed to compile MIL … No space left on device" = the PHONE's disk is full (speech model compiles on-device), not an app bug — now mapped to a friendly message in Transcriber.
