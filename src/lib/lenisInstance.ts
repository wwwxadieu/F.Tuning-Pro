import type Lenis from 'lenis'

let instance: Lenis | null = null

export function setLenisInstance(lenis: Lenis | null) {
  instance = lenis
}

export function getLenisInstance(): Lenis | null {
  return instance
}

export function smoothScrollTo(target: string | HTMLElement, offset = -90) {
  if (instance) {
    instance.scrollTo(target, { offset, duration: 1.1 })
    return
  }
  const el = typeof target === 'string' ? document.querySelector(target) : target
  el?.scrollIntoView({ behavior: 'smooth' })
}
