import type { ProviderTranslator } from '../../types'

import { describe, expect, it } from 'vitest'
import { z } from 'zod'

import { getProviderValidationIntervalMs } from '../../validators/run'
import { providerMlxServe } from './mlx-serve'
import { providerTensorFold } from './tensorfold'

const translate = ((key: string) => key) as ProviderTranslator

const localServers = [
  {
    defaultBaseUrl: 'http://localhost:11234/v1/',
    definition: providerMlxServe,
    name: 'MLX-Serve',
  },
  {
    defaultBaseUrl: 'http://127.0.0.1:8080/v1/',
    definition: providerTensorFold,
    name: 'TensorFold',
  },
] as const

describe('local OpenAI-compatible servers', () => {
  it.each(localServers)('uses the documented default address for $name', async ({ defaultBaseUrl, definition, name }) => {
    const schema = await definition.createProviderConfig({ t: translate })

    expect(z.parse(schema, {}).baseUrl).toBe(defaultBaseUrl)
    expect(definition.name).toBe(name)
  })

  it.each(localServers)('accepts an empty API key for $name', async ({ defaultBaseUrl, definition }) => {
    const validator = await definition.validators?.validateConfig?.[0]({ t: translate })
    const result = await validator?.validator({ baseUrl: defaultBaseUrl }, { t: translate })

    expect(result?.valid).toBe(true)
  })

  it.each(localServers)('reuses the shared OpenAI-compatible probe for $name', async ({ definition }) => {
    const validators = await Promise.all((definition.validators?.validateProvider ?? []).map(create => create({ t: translate })))

    expect(validators.map(validator => validator.id)).toEqual([
      'openai-compatible:check-connectivity',
      'openai-compatible:check-chat-completions',
      'openai-compatible:check-model-list',
    ])
  })

  it.each(localServers)('reuses the 15 second local server schedule for $name', async ({ definition }) => {
    const intervalMs = await getProviderValidationIntervalMs({
      contextOptions: { t: translate },
      definition,
    })

    expect(intervalMs).toBe(15_000)
  })

  it.each(localServers)('creates a chat client for $name', async ({ defaultBaseUrl, definition }) => {
    const provider = await definition.createProvider({ baseUrl: defaultBaseUrl })

    expect(provider).toHaveProperty('chat')
  })
})
