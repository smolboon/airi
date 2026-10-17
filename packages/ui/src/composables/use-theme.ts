import { useColorMode } from '@vueuse/core'
import { computed, watch } from 'vue'

/**
 * Dark is the only theme.
 *
 * A saved light value and the system scheme do not change the document.
 * The first-paint script already adds the `dark` class.
 */
const darkOnlyStorage: Storage = {
  get length() {
    return 0
  },
  clear() {},
  getItem() {
    return 'dark'
  },
  key() {
    return null
  },
  removeItem() {},
  setItem() {},
}

const colorMode = useColorMode({
  disableTransition: true,
  initialValue: 'dark',
  modes: {
    auto: 'dark',
    dark: 'dark',
    light: 'dark',
  },
  onChanged(_mode, apply) {
    apply('dark')
    if (typeof document === 'undefined')
      return

    document.documentElement.classList.add('dark')
    document.documentElement.classList.remove('light')
    document.documentElement.style.colorScheme = 'dark'
  },
  storage: darkOnlyStorage,
})

watch(colorMode.store, (mode) => {
  if (mode !== 'dark')
    colorMode.store.value = 'dark'
})

const isDark = computed({
  get: () => true,
  set: () => {
    colorMode.store.value = 'dark'
  },
})

const themeMode = computed({
  get: () => 'dark' as const,
  set: () => {
    colorMode.store.value = 'dark'
  },
})

function toggleDark() {
  colorMode.store.value = 'dark'
}

function switchToNextTheme() {
  colorMode.store.value = 'dark'
}

export function useTheme() {
  return {
    isDark,
    switchToNextTheme,
    themeMode,
    toggleDark,
  }
}
