#include <stdint.h>

#define SCREEN_W 320
#define SCREEN_H 240
#define FB_ADDR  0x00100000u

#define REG32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

#define VI_STATUS   0xA4400000
#define VI_ORIGIN   0xA4400004
#define VI_WIDTH    0xA4400008
#define VI_V_INTR   0xA440000C
#define VI_CURRENT  0xA4400010
#define VI_BURST    0xA4400014
#define VI_V_SYNC   0xA4400018
#define VI_H_SYNC   0xA440001C
#define VI_LEAP     0xA4400020
#define VI_H_START  0xA4400024
#define VI_V_START  0xA4400028
#define VI_V_BURST  0xA440002C
#define VI_X_SCALE  0xA4400030
#define VI_Y_SCALE  0xA4400034

#define SI_DRAM_ADDR       0xA4800000
#define SI_PIF_ADDR_RD64B  0xA4800004
#define SI_PIF_ADDR_WR64B  0xA4800010
#define SI_STATUS          0xA4800018
#define PIF_RAM_PHYS       0x1FC007C0

#define BTN_DRIGHT 0x0100
#define BTN_DLEFT  0x0200
#define BTN_DDOWN  0x0400
#define BTN_DUP    0x0800
#define BTN_START  0x1000

void *memcpy(void *dst, const void *src, unsigned long n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    for (unsigned long i = 0; i < n; i++) d[i] = s[i];
    return dst;
}

static volatile uint16_t *const fb = (volatile uint16_t *)(uintptr_t)(0xA0000000u + FB_ADDR);
static uint8_t joybuf[64] __attribute__((aligned(64)));

static inline uint32_t phys_addr(const void *p) {
    return ((uint32_t)(uintptr_t)p) & 0x1FFFFFFFu;
}

static inline void wait_si_idle(void) {
    while (REG32(SI_STATUS) & 0x0003u) {}
}

static void si_dma_write(void *dram) {
    wait_si_idle();
    REG32(SI_DRAM_ADDR) = phys_addr(dram);
    REG32(SI_PIF_ADDR_WR64B) = PIF_RAM_PHYS;
    wait_si_idle();
}

static void si_dma_read(void *dram) {
    wait_si_idle();
    REG32(SI_DRAM_ADDR) = phys_addr(dram);
    REG32(SI_PIF_ADDR_RD64B) = PIF_RAM_PHYS;
    wait_si_idle();
}

static void init_video(void) {
    REG32(VI_STATUS) = 0x0000320E;
    REG32(VI_ORIGIN) = FB_ADDR;
    REG32(VI_WIDTH) = SCREEN_W;
    REG32(VI_V_INTR) = 0x0000020;
    REG32(VI_BURST) = 0x03E52239;
    REG32(VI_V_SYNC) = 0x0000020D;
    REG32(VI_H_SYNC) = 0x00000C15;
    REG32(VI_LEAP) = 0x0C150C15;
    REG32(VI_H_START) = 0x006C02EC;
    REG32(VI_V_START) = 0x002501FF;
    REG32(VI_V_BURST) = 0x000E0204;
    REG32(VI_X_SCALE) = 0x00000200;
    REG32(VI_Y_SCALE) = 0x00000400;
}

static void wait_frame(void) {
    uint32_t start = REG32(VI_CURRENT);
    while (REG32(VI_CURRENT) == start) {}
}

static void clear_screen(uint16_t color) {
    for (int i = 0; i < SCREEN_W * SCREEN_H; i++) fb[i] = color;
}

static void rect(int x, int y, int w, int h, uint16_t color) {
    if (x < 0) { w += x; x = 0; }
    if (y < 0) { h += y; y = 0; }
    if (x + w > SCREEN_W) w = SCREEN_W - x;
    if (y + h > SCREEN_H) h = SCREEN_H - y;
    if (w <= 0 || h <= 0) return;

    for (int yy = 0; yy < h; yy++) {
        int row = (y + yy) * SCREEN_W + x;
        for (int xx = 0; xx < w; xx++) fb[row + xx] = color;
    }
}

typedef struct {
    uint16_t buttons;
    int8_t stick_x;
    int8_t stick_y;
} PadState;

typedef struct {
    int x, y;
    int vx, vy;
    int s;
} Enemy;

static PadState read_controller(void) {
    for (int i = 0; i < 64; i++) joybuf[i] = 0;

    joybuf[0] = 0xFF;
    joybuf[1] = 0x01;
    joybuf[2] = 0x04;
    joybuf[3] = 0x01;
    joybuf[4] = 0xFF;
    joybuf[5] = 0xFF;
    joybuf[6] = 0xFF;
    joybuf[7] = 0xFF;
    joybuf[8] = 0xFE;

    si_dma_write(joybuf);
    si_dma_read(joybuf);

    PadState out;
    out.buttons = (uint16_t)((joybuf[4] << 8) | joybuf[5]);
    out.stick_x = (int8_t)joybuf[6];
    out.stick_y = (int8_t)joybuf[7];
    return out;
}

static int overlaps(int ax, int ay, int as, int bx, int by, int bs) {
    return !(ax + as < bx || bx + bs < ax || ay + as < by || by + bs < ay);
}

void game_main(void) {
    init_video();

    Enemy enemies[4] = {
        {16, 20, 2, 1, 9},
        {280, 30, -2, 2, 9},
        {50, 180, 1, -2, 9},
        {240, 170, -1, -1, 9},
    };

    int px = SCREEN_W / 2;
    int py = SCREEN_H / 2;
    int ps = 8;
    int lives = 3;
    int score = 0;
    int pickups = 0;
    int phase = 0;  // 0 title, 1 playing, 2 game over
    int frame = 0;

    int coin_x = 150;
    int coin_y = 100;

    for (;;) {
        PadState pad = read_controller();

        if (phase == 0) {
            if (pad.buttons & BTN_START) phase = 1;
        } else if (phase == 1) {
            if (pad.buttons & BTN_DLEFT) px -= 3;
            if (pad.buttons & BTN_DRIGHT) px += 3;
            if (pad.buttons & BTN_DDOWN) py += 3;
            if (pad.buttons & BTN_DUP) py -= 3;

            px += pad.stick_x / 22;
            py -= pad.stick_y / 22;

            if (px < 3) px = 3;
            if (py < 6) py = 6;
            if (px > SCREEN_W - (ps + 3)) px = SCREEN_W - (ps + 3);
            if (py > SCREEN_H - (ps + 3)) py = SCREEN_H - (ps + 3);

            int speedup = 1 + (score / 480);
            if (speedup > 4) speedup = 4;

            for (int i = 0; i < 4; i++) {
                enemies[i].x += enemies[i].vx * speedup;
                enemies[i].y += enemies[i].vy * speedup;
                if (enemies[i].x < 0 || enemies[i].x > SCREEN_W - enemies[i].s) enemies[i].vx = -enemies[i].vx;
                if (enemies[i].y < 0 || enemies[i].y > SCREEN_H - enemies[i].s) enemies[i].vy = -enemies[i].vy;

                if (overlaps(px, py, ps, enemies[i].x, enemies[i].y, enemies[i].s)) {
                    lives--;
                    px = SCREEN_W / 2;
                    py = SCREEN_H / 2;
                    if (lives <= 0) phase = 2;
                }
            }

            if (overlaps(px, py, ps, coin_x, coin_y, 6)) {
                pickups++;
                score += 300;
                coin_x = 20 + (frame * 37) % (SCREEN_W - 40);
                coin_y = 20 + (frame * 53) % (SCREEN_H - 40);
            }

            score++;
            frame++;
        } else {
            if (pad.buttons & BTN_START) {
                px = SCREEN_W / 2;
                py = SCREEN_H / 2;
                lives = 3;
                score = 0;
                pickups = 0;
                frame = 0;
                phase = 1;
            }
        }

        clear_screen(phase == 2 ? 0x7800 : 0x0011);

        if (phase == 0) {
            rect(70, 70, 180, 100, 0xFFFF);
            rect(74, 74, 172, 92, 0x0000);
            rect(92, 90, 136, 12, 0x07E0);
            rect(102, 112, 116, 12, 0xFFE0);
            rect(112, 134, 96, 12, 0xF800);
        } else {
            rect(0, 0, (score >> 4) % SCREEN_W, 4, 0xFFFF);
            rect(coin_x, coin_y, 6, 6, 0xFFE0);
            rect(px, py, ps, ps, 0x07E0);

            for (int i = 0; i < 4; i++) rect(enemies[i].x, enemies[i].y, enemies[i].s, enemies[i].s, 0xF800);
            for (int i = 0; i < lives; i++) rect(4 + i * 10, 8, 8, 4, 0x07E0);
            for (int i = 0; i < pickups && i < 10; i++) rect(4 + i * 8, 16, 6, 3, 0xFFE0);

            if (phase == 2) {
                rect(80, 92, 160, 56, 0xFFFF);
                rect(84, 96, 152, 48, 0x0000);
                rect(102, 110, 116, 16, 0xF800);
            }
        }

        wait_frame();
    }
}
