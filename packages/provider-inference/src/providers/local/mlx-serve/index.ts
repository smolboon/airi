import { createChatProvider, createEmbedProvider, createModelProvider, merge } from '@xsai-ext/providers/utils'
import { z } from 'zod'

import { ProviderValidationCheck } from '../../../types'
import { createOpenAICompatibleValidators } from '../../../validators'
import { defineProvider } from '../../registry'

const mlxServeConfigSchema = z.object({
  apiKey: z
    .string('API Key')
    .optional(),
  baseUrl: z
    .string('Base URL')
    .optional()
    .default('http://localhost:11234/v1/'),
})

type MlxServeConfig = z.input<typeof mlxServeConfigSchema>

export const providerMlxServe = defineProvider<MlxServeConfig, 'mlx-serve'>({
  id: 'mlx-serve',
  order: 3.1,
  name: 'MLX-Serve',
  nameLocalize: ({ t }) => t('settings.pages.providers.provider.mlx-serve.title'),
  description: 'localhost:11234',
  descriptionLocalize: ({ t }) => t('settings.pages.providers.provider.mlx-serve.description'),
  tasks: ['chat'],
  icon: 'i-solar:cpu-bolt-bold-duotone',
  iconColor: 'text-orange-500',

  createProviderConfig: ({ t }) => mlxServeConfigSchema.extend({
    apiKey: mlxServeConfigSchema.shape.apiKey.meta({
      labelLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.api-key.label'),
      descriptionLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.api-key.description'),
      placeholderLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.api-key.placeholder'),
      type: 'password',
    }),
    baseUrl: mlxServeConfigSchema.shape.baseUrl.meta({
      labelLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.base-url.label'),
      descriptionLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.base-url.description'),
      placeholderLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.base-url.placeholder'),
    }),
  }),
  createProvider(config) {
    return merge(
      createChatProvider({ apiKey: config.apiKey, baseURL: config.baseUrl! }),
      createEmbedProvider({ apiKey: config.apiKey, baseURL: config.baseUrl! }),
      createModelProvider({ apiKey: config.apiKey, baseURL: config.baseUrl! }),
    )
  },

  validationRequiredWhen(config) {
    return !!config.baseUrl?.trim()
  },
  validators: {
    ...createOpenAICompatibleValidators({
      checks: [ProviderValidationCheck.Connectivity, ProviderValidationCheck.ModelList, ProviderValidationCheck.ChatCompletions],
      skipApiKeyCheck: true,
      schedule: {
        mode: 'interval',
        intervalMs: 15_000,
      },
      connectivityFailureReason: ({ errorMessage }) =>
        `MLX-Serve did not respond. Error: ${errorMessage}. Start the local server on port 11234.`,
      modelListFailureReason: ({ errorMessage }) =>
        `MLX-Serve did not list models. Error: ${errorMessage}. Start the local server on port 11234.`,
    }),
  },
})
