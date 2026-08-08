/**
 * The hero backdrop.
 *
 * This replaced a React Three Fiber scene. That scene pulled in three.js — an
 * 819KB chunk on its own — held a live WebGL context, and re-rendered every
 * frame for the whole time the dashboard was open, which is a lot of GPU and
 * battery for decoration behind a headline.
 *
 * These are blurred gradient orbs animated with nothing but CSS transforms.
 * Transform and opacity are composited, so the animation runs off the main
 * thread, costs no JavaScript per frame, and needs no WebGL context at all.
 */
export default function HeroBackdrop() {
  return (
    <div className="hero-backdrop" aria-hidden="true">
      <span className="hero-orb hero-orb--a" />
      <span className="hero-orb hero-orb--b" />
      <span className="hero-orb hero-orb--c" />
      <span className="hero-grid" />
    </div>
  )
}
