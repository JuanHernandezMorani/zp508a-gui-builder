console.log('[renderer] SoundPreview stub loaded')

export function SoundPreview({ path }: { path: string }) {
  return <audio controls src={path}></audio>
}
