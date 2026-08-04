import { Canvas, useFrame } from '@react-three/fiber'
import { Float, MeshDistortMaterial } from '@react-three/drei'
import { Suspense, useRef } from 'react'
import type { Mesh } from 'three'

function Orb({
  position,
  scale,
  color,
  speed,
}: {
  position: [number, number, number]
  scale: number
  color: string
  speed: number
}) {
  const meshRef = useRef<Mesh>(null)

  useFrame((state) => {
    if (!meshRef.current) return
    meshRef.current.rotation.x = state.clock.elapsedTime * speed * 0.15
    meshRef.current.rotation.y = state.clock.elapsedTime * speed * 0.2
  })

  return (
    <Float speed={speed} rotationIntensity={0.4} floatIntensity={1.4}>
      <mesh ref={meshRef} position={position} scale={scale}>
        <icosahedronGeometry args={[1, 6]} />
        <MeshDistortMaterial
          color={color}
          distort={0.35}
          speed={1.5}
          roughness={0.15}
          metalness={0.6}
        />
      </mesh>
    </Float>
  )
}

export default function HeroScene() {
  return (
    <Canvas
      camera={{ position: [0, 0, 7], fov: 40 }}
      dpr={[1, 1.75]}
      gl={{ antialias: true, alpha: true }}
    >
      <Suspense fallback={null}>
        <ambientLight intensity={0.7} />
        <directionalLight position={[5, 5, 5]} intensity={1.4} />
        <directionalLight position={[-5, -3, 2]} intensity={0.5} color="#0A84FF" />
        <pointLight position={[0, 0, 4]} intensity={0.8} color="#BF5AF2" />
        <Orb position={[-1.6, 0.6, 0]} scale={1.5} color="#0A84FF" speed={1} />
        <Orb position={[1.8, -0.4, -1]} scale={1.1} color="#BF5AF2" speed={1.4} />
        <Orb position={[0.4, 1.3, -2]} scale={0.7} color="#FF375F" speed={0.8} />
      </Suspense>
    </Canvas>
  )
}
