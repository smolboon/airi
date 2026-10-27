---
title: Cerebras
description: Configuring the Cerebras chat model in Aori
---

Cerebras provides a chat model in Aori through its compatible API.

::: info Why Cerebras?
Choose Cerebras if you already use its API and want to access the models available to your account from Aori.
:::

## Obtain API Key

Log in to [Cerebras Cloud](https://cloud.cerebras.ai/), then create an API key.

::: warning API Key Security
Do not commit the API key, include it in screenshots, or share it with anyone.
:::

## Configure in Aori

Open **Settings → Providers → Chat → Cerebras** and fill in the **API Key**. The default Base URL is `https://api.cerebras.ai/v1/`.

## Verify configuration

1. **Validate configuration**: Aori validates the configuration automatically as you edit it. If **Ping API** appears, use it for a live request test.
2. **Select Model →**: After validation succeeds, use this button to open **Settings → Modules → Consciousness**, then select the provider and model.

## Troubleshooting

If the API check fails, verify the API Key, account status, and network connection. If Aori cannot load the model list, confirm that the Base URL is unchanged or enter the exact model ID provided by Cerebras manually on the **Consciousness** page.
