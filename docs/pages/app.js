if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
if (!window.location.hash) window.scrollTo(0, 0);

const year = document.querySelector('#year');
if (year) year.textContent = new Date().getFullYear();

const sceneCards = [...document.querySelectorAll('[data-scene-card]')];
const sceneShuffle = document.querySelector('[data-scene-shuffle]');
const sceneStamp = document.querySelector('[data-scene-stamp]');
const sceneNames = ['FOCUS', 'MAKE', 'MOVE', 'ROAM', 'TRAIN'];
let sceneOrder = sceneCards.map((_, index) => index);

function renderSceneDeck() {
  sceneCards.forEach((card) => {
    const position = sceneOrder.indexOf(Number(card.dataset.sceneIndex));
    card.style.setProperty('--deck-position', position);
    card.classList.toggle('is-top', position === 0);
    card.tabIndex = position === 0 ? 0 : -1;
    card.setAttribute('aria-hidden', position === 0 ? 'false' : 'true');
  });

  if (sceneStamp) {
    sceneStamp.firstChild.textContent = `${sceneNames[sceneOrder[0]]}\n`;
    sceneStamp.lastElementChild.textContent = `0${sceneOrder[0] + 1} / 05`;
  }
}

function shuffleScenes() {
  const rest = sceneOrder.slice(1);
  const nextTop = rest.splice(Math.floor(Math.random() * rest.length), 1)[0];
  sceneOrder = [nextTop, ...rest, sceneOrder[0]];
  renderSceneDeck();
}

sceneCards.forEach((card) => card.addEventListener('click', shuffleScenes));
if (sceneShuffle) sceneShuffle.addEventListener('click', shuffleScenes);
if (sceneCards.length) renderSceneDeck();

const revealItems = document.querySelectorAll('.reveal');
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver((entries, currentObserver) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      currentObserver.unobserve(entry.target);
    });
  }, { threshold: 0.12 });
  revealItems.forEach((item) => observer.observe(item));
} else {
  revealItems.forEach((item) => item.classList.add('is-visible'));
}

const video = document.querySelector('[data-demo-video]');
const videoToggle = document.querySelector('[data-video-toggle]');
if (video && videoToggle) {
  videoToggle.addEventListener('click', () => {
    if (video.paused) {
      video.play().catch(() => {});
      videoToggle.innerHTML = '暂停 / 继续 <span aria-hidden="true">Ⅱ</span>';
    } else {
      video.pause();
      videoToggle.innerHTML = '播放 / 暂停 <span aria-hidden="true">▶</span>';
    }
  });
  video.addEventListener('ended', () => {
    videoToggle.innerHTML = '重新播放 <span aria-hidden="true">↻</span>';
  });
}
