const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

const statusEl = document.getElementById("status");
const scoreEl = document.getElementById("score");
const livesEl = document.getElementById("lives");

const GRAVITY = 0.7;
const GROUND_Y = 420;
const LEVEL_WIDTH = 2200;

const keys = new Set();

const player = {
  x: 70,
  y: GROUND_Y - 64,
  w: 44,
  h: 64,
  vx: 0,
  vy: 0,
  speed: 5,
  jump: 14,
  onGround: false,
  lives: 3,
  invuln: 0,
};

const platforms = [
  { x: 210, y: 340, w: 170, h: 24 },
  { x: 510, y: 300, w: 180, h: 24 },
  { x: 840, y: 360, w: 170, h: 24 },
  { x: 1170, y: 320, w: 200, h: 24 },
  { x: 1530, y: 285, w: 220, h: 24 },
  { x: 1880, y: 330, w: 170, h: 24 },
];

const coins = [
  { x: 260, y: 290, r: 12, collected: false },
  { x: 580, y: 250, r: 12, collected: false },
  { x: 900, y: 305, r: 12, collected: false },
  { x: 1240, y: 270, r: 12, collected: false },
  { x: 1630, y: 235, r: 12, collected: false },
  { x: 1970, y: 280, r: 12, collected: false },
  { x: 1760, y: 380, r: 12, collected: false },
  { x: 2140, y: 385, r: 12, collected: false },
];

const enemies = [
  { x: 450, y: GROUND_Y - 30, w: 34, h: 30, dir: 1, min: 360, max: 600 },
  { x: 1030, y: GROUND_Y - 30, w: 34, h: 30, dir: -1, min: 900, max: 1110 },
  { x: 1410, y: GROUND_Y - 30, w: 34, h: 30, dir: 1, min: 1290, max: 1510 },
  { x: 2050, y: GROUND_Y - 30, w: 34, h: 30, dir: -1, min: 1900, max: 2140 },
];

let cameraX = 0;
let gameWon = false;
let gameOver = false;

function overlap(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

function resetPlayerPosition() {
  player.x = 70;
  player.y = GROUND_Y - player.h;
  player.vx = 0;
  player.vy = 0;
  player.invuln = 90;
  cameraX = 0;
}

function updatePlayer() {
  if (keys.has("ArrowLeft") || keys.has("a")) player.vx = -player.speed;
  else if (keys.has("ArrowRight") || keys.has("d")) player.vx = player.speed;
  else player.vx = 0;

  const wantsJump = keys.has(" ") || keys.has("ArrowUp") || keys.has("w");
  if (wantsJump && player.onGround) {
    player.vy = -player.jump;
    player.onGround = false;
  }

  player.vy += GRAVITY;

  player.x = Math.max(0, Math.min(LEVEL_WIDTH - player.w, player.x + player.vx));
  player.y += player.vy;

  player.onGround = false;

  if (player.y + player.h >= GROUND_Y) {
    player.y = GROUND_Y - player.h;
    player.vy = 0;
    player.onGround = true;
  }

  for (const p of platforms) {
    if (
      player.x + player.w > p.x &&
      player.x < p.x + p.w &&
      player.y + player.h >= p.y &&
      player.y + player.h <= p.y + 20 &&
      player.vy >= 0
    ) {
      player.y = p.y - player.h;
      player.vy = 0;
      player.onGround = true;
    }
  }

  if (player.invuln > 0) player.invuln -= 1;

  cameraX = Math.max(0, Math.min(LEVEL_WIDTH - canvas.width, player.x - canvas.width / 2));
}

function updateCoins() {
  for (const coin of coins) {
    if (coin.collected) continue;

    const dx = player.x + player.w / 2 - coin.x;
    const dy = player.y + player.h / 2 - coin.y;
    if (Math.hypot(dx, dy) < coin.r + 18) coin.collected = true;
  }
}

function updateEnemies() {
  for (const e of enemies) {
    e.x += e.dir * 1.8;
    if (e.x < e.min || e.x + e.w > e.max) e.dir *= -1;

    if (overlap(player, e) && player.invuln === 0) {
      player.lives -= 1;
      livesEl.textContent = `Lives: ${player.lives}`;
      if (player.lives <= 0) {
        gameOver = true;
        statusEl.textContent = "Game over! Press R to restart.";
      } else {
        statusEl.textContent = "Ouch! Watch out for enemies.";
        resetPlayerPosition();
      }
    }
  }
}

function drawCloud(x, y) {
  ctx.fillStyle = "#ffffffcc";
  ctx.beginPath();
  ctx.arc(x, y, 18, 0, Math.PI * 2);
  ctx.arc(x + 20, y - 10, 20, 0, Math.PI * 2);
  ctx.arc(x + 43, y, 17, 0, Math.PI * 2);
  ctx.fill();
}

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  drawCloud(120 - cameraX * 0.2, 95);
  drawCloud(440 - cameraX * 0.2, 70);
  drawCloud(760 - cameraX * 0.2, 100);

  ctx.fillStyle = "#5ec050";
  ctx.fillRect(0, GROUND_Y, canvas.width, canvas.height - GROUND_Y);

  ctx.fillStyle = "#9b6d3d";
  for (const p of platforms) {
    const sx = p.x - cameraX;
    if (sx + p.w < 0 || sx > canvas.width) continue;
    ctx.fillRect(sx, p.y, p.w, p.h);
  }

  for (const coin of coins) {
    if (coin.collected) continue;
    const sx = coin.x - cameraX;
    if (sx + coin.r < 0 || sx - coin.r > canvas.width) continue;
    ctx.fillStyle = "#ffd447";
    ctx.beginPath();
    ctx.arc(sx, coin.y, coin.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#e09f00";
    ctx.stroke();
  }

  for (const e of enemies) {
    const sx = e.x - cameraX;
    if (sx + e.w < 0 || sx > canvas.width) continue;
    ctx.fillStyle = "#7d3f00";
    ctx.fillRect(sx, e.y, e.w, e.h);
    ctx.fillStyle = "#fff";
    ctx.fillRect(sx + 7, e.y + 8, 6, 6);
    ctx.fillRect(sx + 21, e.y + 8, 6, 6);
  }

  if (player.invuln % 12 < 6) {
    const px = player.x - cameraX;
    ctx.fillStyle = "#d82727";
    ctx.fillRect(px + 6, player.y, player.w - 12, 18);
    ctx.fillStyle = "#2643e0";
    ctx.fillRect(px + 10, player.y + 18, player.w - 20, player.h - 18);
    ctx.fillStyle = "#ffd5b2";
    ctx.fillRect(px + 12, player.y + 4, player.w - 24, 10);
  }

  const finishX = LEVEL_WIDTH - 40 - cameraX;
  ctx.fillStyle = "#222";
  ctx.fillRect(finishX, GROUND_Y - 100, 10, 100);
  ctx.fillStyle = "#ff2f2f";
  ctx.beginPath();
  ctx.moveTo(finishX + 10, GROUND_Y - 100);
  ctx.lineTo(finishX + 70, GROUND_Y - 75);
  ctx.lineTo(finishX + 10, GROUND_Y - 50);
  ctx.closePath();
  ctx.fill();
}

function updateHud() {
  const collected = coins.filter((c) => c.collected).length;
  scoreEl.textContent = `Coins: ${collected} / ${coins.length}`;

  if (!gameWon && collected === coins.length && player.x > LEVEL_WIDTH - 120) {
    gameWon = true;
    statusEl.textContent = "You win! Press R to play again.";
  }
}

function restart() {
  for (const c of coins) c.collected = false;
  player.lives = 3;
  livesEl.textContent = "Lives: 3";
  gameWon = false;
  gameOver = false;
  statusEl.textContent = "Collect all coins!";
  resetPlayerPosition();
}

function tick() {
  if (!gameOver && !gameWon) {
    updatePlayer();
    updateCoins();
    updateEnemies();
    updateHud();
  }

  draw();
  requestAnimationFrame(tick);
}

window.addEventListener("keydown", (e) => {
  const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
  keys.add(key);
  if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " "].includes(e.key)) e.preventDefault();

  if ((gameWon || gameOver) && key === "r") restart();
});

window.addEventListener("keyup", (e) => {
  const key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
  keys.delete(key);
});

restart();
requestAnimationFrame(tick);
