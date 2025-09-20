import { useEffect, useRef, useState } from 'react'

type SpritePreviewProps = {
  path: string
  className?: string
}

function buildSpritePreviewUrl(path: string) {
  if (!path) return null
  const normalized = path.replace(/\\/g, '/').toLowerCase()
  return `zpb://sprites/${normalized.replace(/\.spr$/i, '.png')}`
}

export function SpritePreview({ path, className }: SpritePreviewProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const url = buildSpritePreviewUrl(path)
    if (!url) {
      setError('Ruta de sprite no proporcionada.')
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      return
    }

    const img = new Image()
    img.onload = () => {
      canvas.width = img.width
      canvas.height = img.height
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      ctx.drawImage(img, 0, 0)
      setError(null)
    }
    img.onerror = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)
      setError('No se pudo cargar la vista previa del sprite.')
    }
    img.src = url
  }, [path])

  return (
    <div className={className} style={{ position: 'relative', width: 'fit-content' }}>
      <canvas ref={canvasRef} style={{ imageRendering: 'pixelated', background: '#111827', borderRadius: 8 }} />
      {error && (
        <div
          style={{
            position: 'absolute',
            inset: 4,
            background: 'rgba(17, 24, 39, 0.85)',
            color: '#f9fafb',
            padding: '4px 6px',
            borderRadius: 6,
            fontSize: 12
          }}
        >
          {error}
        </div>
      )}
    </div>
  )
}

export default SpritePreview
