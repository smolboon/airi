import { describe, expect, it } from 'vitest'

import { resolveProviderAttributes } from './attributes'

describe('local inference provider attributes', () => {
  it.each(['lm-studio', 'mlx-serve', 'ollama', 'tensorfold'])('marks %s as a free local provider', (id) => {
    expect(resolveProviderAttributes({ id })).toEqual({
      deployment: 'local',
      pricing: 'free',
    })
  })
})
