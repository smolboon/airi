<script setup lang="ts">
import { PartAnimatedWave, PatternCross } from '.'
</script>

<template>
  <PatternCross>
    <PartAnimatedWave
      fill-color="oklch(35% calc(var(--chromatic-chroma) * 0.6) var(--chromatic-hue))"
      class="h-full w-full"
    >
      <div class="relative h-full w-full from-black/10 via-black/0 to-black/0 bg-gradient-to-b" />
    </PartAnimatedWave>
  </PatternCross>
</template>
