import type { SpineVersion } from './spine-version'

/**
 * Lazily loads the spine-webgl runtime for the given Spine version.
 *
 * Use when:
 * - The skeleton version has been detected and we need the matching runtime
 *   to parse and render the model correctly.
 *
 * Expects:
 * - A valid SpineVersion ('4.0', '4.1', or '4.2').
 *
 * Returns:
 * - The full spine-webgl module namespace for that version.
 */
export async function loadSpineRuntime(version: SpineVersion): Promise<typeof import('@esotericsoftware/spine-webgl')> {
  switch (version) {
    case '4.0':
      return castUnknown<(typeof import('@esotericsoftware/spine-webgl'))>(await import('@esotericsoftware/spine-webgl-4-0'))
    case '4.1':
      return castUnknown<(typeof import('@esotericsoftware/spine-webgl'))>(await import('@esotericsoftware/spine-webgl-4-1'))
    case '4.2':
      return await import('@esotericsoftware/spine-webgl')
  }
}

function castUnknown<T>(value: unknown): T {
  return value as T
}
