import { createChatProvider, createEmbedProvider, createModelProvider, merge } from '@xsai-ext/providers/utils'
import { z } from 'zod'

import { ProviderValidationCheck } from '../../../types'
import { createOpenAICompatibleValidators } from '../../../validators'
import { defineProvider } from '../../registry'

const tensorFoldConfigSchema = z.object({
  apiKey: z
    .string('API Key')
    .optional(),
  baseUrl: z
    .string('Base URL')
    .optional()
    .default('http://127.0.0.1:8080/v1/'),
})

type TensorFoldConfig = z.input<typeof tensorFoldConfigSchema>

export const providerTensorFold = defineProvider<TensorFoldConfig, 'tensorfold'>({
  id: 'tensorfold',
  order: 3.2,
  name: 'TensorFold',
  nameLocalize: ({ t }) => t('settings.pages.providers.provider.tensorfold.title'),
  description: '127.0.0.1:8080',
  descriptionLocalize: ({ t }) => t('settings.pages.providers.provider.tensorfold.description'),
  tasks: ['chat'],
  icon: 'i-solar:server-square-bold-duotone',
  iconColor: 'text-teal-500',

  createProviderConfig: ({ t }) => tensorFoldConfigSchema.extend({
    apiKey: tensorFoldConfigSchema.shape.apiKey.meta({
      labelLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.api-key.label'),
      descriptionLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.api-key.description'),
      placeholderLocalized: t('settings.pages.providers.catalog.edit.config.common.fields.field.api-key.placeholder'),
      type: 'password',
    }),
    baseUrl: tensorFoldConfigSchema.shape.baseUrl.meta({
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
        `TensorFold did not respond. Error: ${errorMessage}. Start the local server on port 8080.`,
      modelListFailureReason: ({ errorMessage }) =>
        `TensorFold did not list models. Error: ${errorMessage}. Start the local server on port 8080.`,
    }),
  },
})
