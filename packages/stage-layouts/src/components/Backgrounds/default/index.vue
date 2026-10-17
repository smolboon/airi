<script setup lang="ts">
import { PartAnimatedWave, PatternCross } from '.'
</script>

<template>
  <PatternCross>
    <PartAnimatedWave
      fill-color="oklch(35% calc(var(--chromatic-chroma) * 0.6) var(--chromatic-hue))"
      class="h-full w-full"
    >
      <slot />
    </PartAnimatedWave>
  </PatternCross>
</template>
