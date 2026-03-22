import './style.css'
import { renderNav } from './components/nav.js'
import { renderFooter } from './components/footer.js'

const DOWNLOAD_URL = 'https://github.com/jpomykala/NotchPrompter/releases/download/2.0.3/notch-prompter.app.zip'

renderNav()
renderFooter()

document.querySelectorAll('[data-download-link]').forEach(el => {
  el.href = DOWNLOAD_URL
})
