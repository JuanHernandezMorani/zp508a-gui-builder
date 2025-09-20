import { useMemo, useState } from 'react'

type SoundPreviewProps = {
  path: string
  className?: string
}

function resolveSoundSources(path: string) {
  if (!path) return []
  const normalized = path.replace(/\\/g, '/').toLowerCase()
  return [`zpb://sounds/${normalized}`, `zpb://input/${normalized}`]
}

export function SoundPreview({ path, className }: SoundPreviewProps) {
  const [fallbackIndex, setFallbackIndex] = useState(0)
  const [error, setError] = useState<string | null>(null)
  const sources = useMemo(() => resolveSoundSources(path), [path])

  const currentSrc = sources[fallbackIndex] || path

  return (
    <div className={className} style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <audio
        controls
        src={currentSrc}
        onError={() => {
          if (fallbackIndex + 1 < sources.length) {
            setFallbackIndex(fallbackIndex + 1)
            setError(null)
          } else {
            setError('No se pudo cargar el sonido.')
          }
        }}
      >
        Tu navegador no soporta audio embebido.
      </audio>
      {error && <span style={{ fontSize: 12, color: '#f87171' }}>{error}</span>}
    </div>
  )
}

export default SoundPreview
