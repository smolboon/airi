<script setup lang="ts">
import { RouterLink } from 'vue-router'

import LogoDark from '../../assets/logo-dark.svg'
</script>

<template>
  <RouterLink
    to="/"
    :class="[
      'w-max',
      'flex items-center gap-2',
      'px-2 text-nowrap text-2xl outline-none',
    ]"
  >
    <img :src="LogoDark" alt="" :class="['theme-colored h-8 w-8']">
    <div :class="['translate-y-[2px] font-quicksand font-semibold']">
      <span>Aori</span>
    </div>
  </RouterLink>
</template>

<style scoped>
.theme-colored {
  filter: hue-rotate(calc(var(--chromatic-hue, 0) * 1deg));
}
</style>
