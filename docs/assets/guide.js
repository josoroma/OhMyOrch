/* Progressive enhancement. All guide content and navigation work without JavaScript. */
const themeButton = document.querySelector('.theme-toggle');
const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
let preference = null;
try { preference = localStorage.getItem('ohmyorch-guide-theme'); } catch { /* Storage can be disabled. */ }
if (!['light', 'dark'].includes(preference)) preference = null;
function applyTheme(theme) {
  document.documentElement.classList.toggle('dark', theme === 'dark');
  document.documentElement.dataset.theme = theme;
  document.querySelector('meta[name="theme-color"]').content = theme === 'dark' ? '#0a0a0a' : '#ffffff';
  themeButton.textContent = theme === 'dark' ? 'Light mode' : 'Dark mode';
  themeButton.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
}
applyTheme(preference ?? (systemTheme.matches ? 'dark' : 'light'));
themeButton.addEventListener('click', () => {
  preference = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
  applyTheme(preference);
  try { localStorage.setItem('ohmyorch-guide-theme', preference); } catch { /* Theme still works. */ }
});
systemTheme.addEventListener('change', event => {
  if (!preference) applyTheme(event.matches ? 'dark' : 'light');
});

const toc = document.querySelector('.contents details');
if (window.matchMedia('(max-width: 760px)').matches) toc.open = false;
document.querySelectorAll('pre > code').forEach(code => {
  if (!navigator.clipboard?.writeText) return;
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'copy-button';
  button.textContent = 'Copy';
  button.setAttribute('aria-label', 'Copy command example');
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(code.textContent);
      button.textContent = 'Copied';
    } catch { button.textContent = 'Select to copy'; }
    setTimeout(() => { button.textContent = 'Copy'; }, 2000);
  });
  code.parentElement.append(button);
});
const links = [...document.querySelectorAll('.contents a')];
const headings = [...document.querySelectorAll('article h2')];
let queued = false;
function updateCurrentSection() {
  let current = null;
  for (const heading of headings) {
    if (heading.getBoundingClientRect().top > window.innerHeight * .25) break;
    current = heading.id;
  }
  links.forEach(link => {
    if (link.hash === `#${current}`) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  });
  queued = false;
}
window.addEventListener('scroll', () => {
  if (!queued) {
    queued = true;
    requestAnimationFrame(updateCurrentSection);
  }
}, { passive: true });
updateCurrentSection();
