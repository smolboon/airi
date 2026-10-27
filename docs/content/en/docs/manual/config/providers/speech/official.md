---
title: Official Speech Provider (TTS)
description: Use officially provided speech synthesis in Aori
---

Official speech synthesis uses your active Aori session; no third-party API Key is required.

::: info Why choose Aori official speech synthesis?
If you already use an official Aori provider and want to reduce third-party credential configuration, try this option first.
:::

## Log in to your account

1. Sign in with an Aori account.
2. Confirm that the official speech provider is available for the current session.

::: warning Account and service availability
Available models, quotas, and regions are determined by the official service. Do not share account sessions or browser session data.
:::

## Configure in Aori

1. Open **Settings → Providers → Speech → Official Speech Provider**.
2. If prompted, sign in. Confirm that the page shows your Flux balance and a valid connection status.

## Verify configuration

1. Open **Settings → Modules → Speech**, select **Official Speech Provider**, and choose an available model and voice.
2. Enter a short test sentence, click **Test Voice**, and confirm that Aori plays the generated audio.

## Optional streaming provider

When the official service reports streaming TTS as available, Aori shows a separate **Official Streaming Speech Provider** card under **Settings → Providers → Speech**.

In **Settings → Modules → Speech**, keep **Official Speech Provider** selected. Aori includes the streaming models in that provider's model list. Select a streaming model and voice; Aori then switches the internal speech provider automatically to match the selected model.

## Troubleshooting

If the provider is unavailable, confirm that you are signed in and that Aori can reach the official service. Also confirm that your account has enough Flux. Open **Settings → Flux** to view the available packages. The Desktop ver. opens checkout in the system browser. A purchase option does not appear if the build or deployment does not support purchases.
