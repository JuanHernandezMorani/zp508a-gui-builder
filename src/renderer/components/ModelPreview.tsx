import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'

type ModelPreviewProps = {
  path: string
  className?: string
}

function buildTextureUrl(path: string) {
  if (!path) return null
  const normalized = path.replace(/\\/g, '/').toLowerCase()
  return `zpb://models/${normalized.replace(/\.mdl$/i, '.png')}`
}

export function ModelPreview({ path, className }: ModelPreviewProps) {
  const mountRef = useRef<HTMLDivElement | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const container = mountRef.current
    if (!container) return undefined

    const width = container.clientWidth || 240
    const height = container.clientHeight || 200
    const scene = new THREE.Scene()
    scene.background = new THREE.Color(0x111111)
    const camera = new THREE.PerspectiveCamera(35, width / height, 0.1, 100)
    camera.position.set(0, 0, 3)

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    renderer.setSize(width, height)
    renderer.setPixelRatio(window.devicePixelRatio || 1)
    container.appendChild(renderer.domElement)

    const hemi = new THREE.HemisphereLight(0xffffff, 0x222222, 1.1)
    scene.add(hemi)

    const group = new THREE.Group()
    scene.add(group)

    let frame = 0
    const animate = () => {
      frame = requestAnimationFrame(animate)
      group.rotation.y += 0.01
      renderer.render(scene, camera)
    }

    const cleanup = () => {
      cancelAnimationFrame(frame)
      group.clear()
      renderer.dispose()
      if (renderer.domElement && renderer.domElement.parentNode === container) {
        container.removeChild(renderer.domElement)
      }
    }

    const textureUrl = buildTextureUrl(path)
    if (textureUrl) {
      const loader = new THREE.TextureLoader()
      loader.load(
        textureUrl,
        (texture) => {
          const geometry = new THREE.PlaneGeometry(1.5, 1.5)
          const material = new THREE.MeshBasicMaterial({ map: texture, transparent: true })
          const mesh = new THREE.Mesh(geometry, material)
          group.add(mesh)
          setError(null)
          animate()
        },
        undefined,
        () => {
          const geometry = new THREE.BoxGeometry(1.2, 1.2, 1.2)
          const material = new THREE.MeshStandardMaterial({ color: 0x1f2937, metalness: 0.1, roughness: 0.7 })
          const mesh = new THREE.Mesh(geometry, material)
          group.add(mesh)
          setError('Vista previa no disponible, usando representación genérica.')
          animate()
        }
      )
    } else {
      const geometry = new THREE.BoxGeometry(1.2, 1.2, 1.2)
      const material = new THREE.MeshStandardMaterial({ color: 0x1f2937, metalness: 0.1, roughness: 0.7 })
      const mesh = new THREE.Mesh(geometry, material)
      group.add(mesh)
      setError('Ruta de modelo no proporcionada.')
      animate()
    }

    return cleanup
  }, [path])

  return (
    <div className={className} style={{ position: 'relative' }}>
      <div ref={mountRef} style={{ width: '100%', height: '200px' }} />
      {error && (
        <div
          style={{
            position: 'absolute',
            inset: 8,
            background: 'rgba(17, 24, 39, 0.85)',
            color: '#f9fafb',
            borderRadius: 8,
            fontSize: 12,
            padding: '6px 8px'
          }}
        >
          {error}
        </div>
      )}
    </div>
  )
}

export default ModelPreview
