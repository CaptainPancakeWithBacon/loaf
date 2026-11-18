// Loaf for the Claude app: Loaf's paper and ink (accent in ink, so no blue), and Loaf's cat napping in the
// bottom right corner behind the conversation. Nothing moves; light and dark follow the app.
import type { Register } from 'claude-code'
import { colors } from './colors'

// The cat from Loaf's logo with its eyes shut, three times its size, just above the bottom edge.
// The style block follows the app's light or dark mode (the desktop draws this as an image).
const NAP = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 1000" preserveAspectRatio="xMaxYMax slice">
<style>
.g{fill:#F1EDE4}.c{fill:#D5CDBE}.l{fill:none;stroke:#F1EDE4;stroke-width:4.5;stroke-linecap:round}
.z{fill:none;stroke:#C2B9A8;stroke-width:3.2;stroke-linecap:round;stroke-linejoin:round}
@media (prefers-color-scheme: dark){.g{fill:#121212}.c{fill:#252524}.l{stroke:#121212}.z{stroke:#343432}}
</style>
<rect class="g" width="1600" height="1000"/>
<g transform="translate(930 400) scale(3)">
<path class="c" d="M72 112 C67 84 73 60 86 42 C100 56 112 70 118 82 Z"/>
<path class="c" d="M184 112 C189 84 183 60 170 42 C156 56 144 70 138 82 Z"/>
<path class="c" d="M64 134 C62 102 88 80 128 80 C168 80 194 102 192 134 C194 160 176 180 128 184 C80 180 62 160 64 134 Z"/>
<path class="l" d="M91 131 Q104 141 117 131 M139 131 Q152 141 165 131"/>
<path class="z" d="M196 52 H208 L196 66 H208"/>
<path class="z" d="M210 28 H218 L210 38 H218"/>
</g>
</svg>`

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    // glass: the app's own panel colour (which follows this theme) over the cat, lightly frosted
    const set = await $.theme.set({ colors, backdrop: { scene: 'nap', glass: { blur: 12, opacity: 0.85 } } })
    // only a real problem shows: the app's reason for not drawing it
    $.ui.status(set.isDrawn ? undefined : `Loaf theme: ${set.reason}`)
    return next(e)
  })

  on('ui.render', { component: 'Backdrop' }, ($, e, next) => {
    if ((e.surface !== 'desktop' && e.surface !== 'mobile') || e.props.scene !== 'nap' || e.props.plugin !== 'loaf-theme') {
      return next(e)
    }
    const { Svg } = $.ui.resolve(e)
    return <Svg source={NAP} alt="Loaf's cat napping in the corner" />
  })

  // The working line says what the dough is doing. The desktop's own step text ("Creating notes.md") stays;
  // only its plain "Working" and the terminal's random word are replaced.
  on('ui.render', { component: 'Spinner' }, ($, e, next) => {
    if (e.surface === 'desktop' && e.props.word !== 'Working') return next(e)
    return next({ ...e, props: { ...e.props, word: BAKE[e.props.mode] } })
  })

  // The empty prompt asks the question first; the engine's key hint stays after it.
  on('ui.render', { component: 'PromptHint' }, ($, e, next) => {
    if (e.props.isDraft || e.props.isWorking) return next(e)
    return next({ ...e, props: { ...e.props, hint: `What shall we bake? ${e.props.hint}` } })
  })
}

const BAKE = {
  thinking: 'Proofing',
  requesting: 'Rising',
  'tool-input': 'Kneading',
  'tool-use': 'Kneading',
  responding: 'Baking',
} as const
