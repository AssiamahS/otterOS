# otterOS NOTES

- 2026-08-06: bing serves real HTML only to curl UAs; expat broken in brew python (regex-parse XML). ASC cert cap = revoke Created-via-API dev certs (DELETE /v1/certificates). exportArchive "Error Downloading App Information" = missing ASC app record — POST /v1/apps is 403, create in UI.
- iOS cannot record cellular call audio (any version, incl. 26) — mic+speakerphone is the Otter pattern; REC indicator required (guideline 2.5.14).
- SpeechTranscriber (iOS 26): locale must come from supportedLocales (bcp47); finalizeAndFinishThroughEndOfInput() on stop or the volatile tail is lost; convert engine buffers to bestAvailableAudioFormat.
