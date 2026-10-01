// ============================================================
// Theme -- Config.Theme (config.lua) is pushed once via SendNUIMessage on
// load (client.lua's sendTheme()) and written onto :root as CSS custom
// properties. Every color below picks between var(--hud-color-x-state)
// NAMES rather than resolving to a hex value in JS, so the browser always
// reads the live value -- no caching, no race against that one-time message.
// HUD_THRESHOLDS holds the few NUMERIC cutoffs (e.g. "hunger critical below
// 30") that also come from config.lua, with the shipped defaults as a
// fallback for the brief window before that message arrives.
// ============================================================
const HUD_THRESHOLDS = {
    hunger: { criticalBelow: 30 },
    thirst: { criticalBelow: 30 },
    fuel: { warnBelow: 30, criticalBelow: 20 },
};

function applyTheme(data) {
    const root = document.documentElement.style;
    const theme = (data && data.theme) || {};
    if (theme.accent) {
        root.setProperty('--hud-accent', theme.accent);
        const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(theme.accent);
        if (m) root.setProperty('--hud-accent-rgb', `${parseInt(m[1], 16)}, ${parseInt(m[2], 16)}, ${parseInt(m[3], 16)}`);
    }
    ['health', 'armor', 'hunger', 'thirst', 'engine', 'fuel'].forEach((key) => {
        if (!theme[key]) return;
        ['ok', 'warn', 'critical'].forEach((state) => {
            if (theme[key][state]) root.setProperty(`--hud-color-${key}-${state}`, theme[key][state]);
        });
        if (HUD_THRESHOLDS[key]) HUD_THRESHOLDS[key] = Object.assign({}, HUD_THRESHOLDS[key], theme[key]);
    });
}

window.addEventListener('message', (event) => {
    if (event.data && event.data.action === 'theme') applyTheme(event.data);
});

// FiveM's CEF browser can treat a mouse-wheel scroll over this page as a
// page-zoom gesture (Chromium's Ctrl+wheel zoom, or the wheel event arriving
// with ctrlKey already set by the OS/game) instead of just content scroll --
// reported in-game 2026-09-21 (scrolling the settings menu list zoomed the
// whole HUD AND the game camera behind it). Only block the zoom-flagged
// case; a plain wheel event still scrolls `.menu-body`'s own overflow-y
// normally, so this never breaks the actual scrolling.
window.addEventListener('wheel', (e) => {
    if (e.ctrlKey) e.preventDefault();
}, { passive: false });

// ============================================================
// SETTINGS MENU
// ============================================================

// One entry per toggle. `key` is the Menu.* field client.lua owns (it pushes
// the real value with { event: key, toggle: value }); `action` is the NUI
// callback that flips it Lua-side. `on`/`off` are the stored values that mean
// "card switched on" / "off" -- several Lua flags are phrased the other way
// round from their card (e.g. isHideMapChecked = true means the map is OFF),
// so the card never shows an inverted state.
const MENU_TABS = [
    {
        key: 'minimap', label: 'Minimap', icon: 'fas fa-map-marked-alt',
        desc: 'Radar shape, frame and visibility',
        items: [
            { key: 'isHideMapChecked', action: 'HideMap', on: false, off: true, icon: 'fas fa-map', label: 'Minimap enabled', desc: 'Show the radar at all' },
            { key: 'isToggleMapShapeChecked', action: 'ToggleMapShape', on: 'circle', off: 'square', icon: 'fas fa-circle-notch', label: 'Round minimap', desc: 'NoPixel-style circle. Off = square' },
            { key: 'isToggleMapBordersChecked', action: 'ToggleMapBorders', icon: 'fas fa-dot-circle', label: 'Minimap frame', desc: 'Dark ring + white edge around the map' },
            { key: 'isPointerShowChecked', action: 'showPointerIndex', icon: 'fas fa-location-arrow', label: 'N / E / S / W letters', desc: 'Cardinal letters riding the map ring' },
            { key: 'isOutMapChecked', action: 'showOutMap', on: false, off: true, icon: 'fas fa-car-side', label: 'Only in vehicle', desc: 'Hide the minimap while on foot' },
        ],
    },
    {
        key: 'compass', label: 'Compass & Streets', icon: 'fas fa-compass',
        desc: 'Heading above the map, zone and street below it',
        items: [
            { key: 'isShowCompassChecked', action: 'showCompassBase', icon: 'fas fa-compass', label: 'Heading display', desc: 'The 072° box above the minimap' },
            { key: 'isDegreesShowChecked', action: 'showDegreesNum', icon: 'fas fa-ruler-combined', label: 'Heading in degrees', desc: 'Off = direction letters (NE, SW…)' },
            { key: 'isShowStreetsChecked', action: 'showStreetsNames', icon: 'fas fa-road', label: 'Zone & street names', desc: 'ALTA / OCCUPATION AVENUE under the map' },
            { key: 'isCompassFollowChecked', action: 'showFollowCompass', icon: 'fas fa-video', label: 'Follow camera', desc: 'Heading follows the camera, not your body' },
            { key: 'isOutCompassChecked', action: 'showOutCompass', on: false, off: true, icon: 'fas fa-walking', label: 'Only in vehicle', desc: 'Hide heading & streets while on foot' },
        ],
    },
    {
        key: 'status', label: 'Status Bars', icon: 'fas fa-heartbeat',
        desc: 'Which stats stay on screen all the time',
        items: [
            { key: 'isDynamicHealthChecked', action: 'dynamicHealth', on: false, off: true, icon: 'fas fa-heartbeat', label: 'Always show health', desc: 'Off = only while hurt' },
            { key: 'isDynamicArmorChecked', action: 'dynamicArmor', on: false, off: true, icon: 'fas fa-shield-alt', label: 'Always show armor', desc: 'Off = only while wearing armor' },
            { key: 'isDynamicHungerChecked', action: 'dynamicHunger', on: false, off: true, icon: 'fas fa-hamburger', label: 'Always show hunger', desc: 'Off = only when not full' },
            { key: 'isDynamicThirstChecked', action: 'dynamicThirst', on: false, off: true, icon: 'fas fa-glass-whiskey', label: 'Always show thirst', desc: 'Off = only when not full' },
            { key: 'isDynamicStressChecked', action: 'dynamicStress', on: false, off: true, icon: 'fas fa-brain', label: 'Always show stress', desc: 'Off = only while stressed' },
            { key: 'isDynamicOxygenChecked', action: 'dynamicOxygen', on: false, off: true, icon: 'fas fa-lungs', label: 'Always show oxygen', desc: 'Off = only while running / diving' },
            { key: 'isDynamicEngineChecked', action: 'dynamicEngine', on: false, off: true, icon: 'fas fa-oil-can', label: 'Always show engine', desc: 'Off = only when damaged' },
            { key: 'isDynamicNitroChecked', action: 'dynamicNitro', on: false, off: true, icon: 'fas fa-meteor', label: 'Always show nitro', desc: 'Off = only when installed' },
        ],
    },
    {
        key: 'display', label: 'Display', icon: 'fas fa-desktop',
        desc: 'Performance and cinematic mode',
        items: [
            { key: 'isChangeFPSChecked', action: 'changeFPS', on: 'Optimized', off: 'Synced', icon: 'fas fa-microchip', label: 'Optimized HUD refresh', desc: 'Update stats twice a second — saves FPS' },
            { key: 'isChangeCompassFPSChecked', action: 'changeCompassFPS', icon: 'fas fa-tachometer-alt', label: 'Optimized compass', desc: '20 updates / sec instead of every frame' },
            { key: 'isCinematicModeChecked', action: 'cinematicMode', icon: 'fas fa-film', label: 'Cinematic mode', desc: 'Black bars, HUD & minimap hidden' },
        ],
    },
    {
        key: 'alerts', label: 'Sound & Alerts', icon: 'fas fa-bell',
        desc: 'Sound effects and notifications',
        items: [
            { key: 'isOpenMenuSoundsChecked', action: 'openMenuSounds', icon: 'fas fa-volume-up', label: 'Menu sounds', desc: 'Open / close sound effect' },
            { key: 'isListSoundsChecked', action: 'checklistSounds', icon: 'fas fa-mouse-pointer', label: 'Click sounds', desc: 'Sound when flipping a setting' },
            { key: 'isResetSoundsChecked', action: 'resetHudSounds', icon: 'fas fa-wrench', label: 'Reset sounds', desc: 'Sound when the HUD reloads' },
            { key: 'isLowFuelChecked', action: 'showFuelAlert', icon: 'fas fa-gas-pump', label: 'Low fuel alert', desc: 'Pager beep + notify under 20% fuel' },
            { key: 'isMapNotifChecked', action: 'showMapNotif', icon: 'fas fa-map-pin', label: 'Minimap notifications', desc: 'Notify when the minimap reloads' },
            { key: 'isCinematicNotifChecked', action: 'showCinematicNotif', icon: 'fas fa-comment-alt', label: 'Cinematic notifications', desc: 'Notify when cinematic mode toggles' },
        ],
    },
];

// Fallbacks for the instant before client.lua's first sync arrives
// (mirrors Config.Menu in config.lua).
const MENU_DEFAULTS = {
    isOutMapChecked: false, isOutCompassChecked: false, isCompassFollowChecked: true,
    isOpenMenuSoundsChecked: true, isResetSoundsChecked: true, isListSoundsChecked: true,
    isMapNotifChecked: true, isLowFuelChecked: true, isCinematicNotifChecked: true,
    isDynamicHealthChecked: false, isDynamicArmorChecked: false, isDynamicHungerChecked: false,
    isDynamicThirstChecked: false, isDynamicStressChecked: true, isDynamicOxygenChecked: true,
    isChangeFPSChecked: 'Optimized', isHideMapChecked: false, isToggleMapBordersChecked: true,
    isDynamicEngineChecked: true, isDynamicNitroChecked: true, isChangeCompassFPSChecked: true,
    isShowCompassChecked: true, isShowStreetsChecked: true, isPointerShowChecked: true,
    isDegreesShowChecked: true, isCinematicModeChecked: false, isToggleMapShapeChecked: 'circle',
};

function nuiPost(name) {
    $.post('https://aj-hud/' + name);
}

const app = Vue.createApp({
    data() {
        let activeTab = 'minimap';
        try {
            const saved = localStorage.getItem('menuActiveTab');
            if (MENU_TABS.some((t) => t.key === saved)) activeTab = saved;
        } catch (e) { /* storage unavailable */ }
        return Object.assign({
            tabs: MENU_TABS,
            activeTab,
            searchQuery: '',
            confirmReset: false,
            openCount: 0,
            openKey: 'I',
        }, MENU_DEFAULTS);
    },
    computed: {
        isSearching() {
            return this.searchQuery.trim().length > 0;
        },
        currentTab() {
            return this.tabs.find((t) => t.key === this.activeTab) || this.tabs[0];
        },
        visibleGroups() {
            if (!this.isSearching) return [this.currentTab];
            const q = this.searchQuery.trim().toLowerCase();
            return this.tabs
                .map((t) => ({ key: t.key, label: t.label, items: t.items.filter((i) => (i.label + ' ' + i.desc).toLowerCase().includes(q)) }))
                .filter((g) => g.items.length > 0);
        },
        resultCount() {
            return this.visibleGroups.reduce((n, g) => n + g.items.length, 0);
        },
    },
    watch: {
        activeTab(v) {
            try { localStorage.setItem('menuActiveTab', v); } catch (e) { /* ignore */ }
        },
    },
    methods: {
        onValue(item) { return item.on === undefined ? true : item.on; },
        offValue(item) { return item.off === undefined ? false : item.off; },
        isOn(item) { return this[item.key] === this.onValue(item); },
        activeCount(tab) { return tab.items.filter((i) => this.isOn(i)).length; },
        // Sets the local copy exactly once, then lets Lua flip its own value
        // (it toggles, so the two stay in step; the next sync corrects any drift).
        toggle(item) {
            this[item.key] = this.isOn(item) ? this.offValue(item) : this.onValue(item);
            nuiPost(item.action);
        },
        setActiveTab(key) {
            this.activeTab = key;
            this.searchQuery = '';
        },
        closeMenu() {
            this.confirmReset = false;
            closeMenu();
        },
        restartHud() {
            this.closeMenu();
            nuiPost('restartHud');
        },
        resetStorage() {
            if (!this.confirmReset) {
                this.confirmReset = true;
                clearTimeout(this.confirmTimer);
                this.confirmTimer = setTimeout(() => (this.confirmReset = false), 3000);
                return;
            }
            clearTimeout(this.confirmTimer);
            this.closeMenu();
            nuiPost('resetStorage');
        },
    },
    mounted() {
        window.addEventListener('message', (event) => {
            const d = event.data || {};
            if (d.event && Object.prototype.hasOwnProperty.call(MENU_DEFAULTS, d.event)) {
                this[d.event] = d.toggle;
            } else if (d.action === 'open') {
                this.openCount += 1;
                this.searchQuery = '';
                this.confirmReset = false;
                openMenuEl();
            } else if (d.action === 'theme' && d.openKey) {
                this.openKey = String(d.openKey).toUpperCase();
            }
        });
    },
});

app.mount('#menu');

// Explicit flag instead of jQuery's :visible -- a half-finished fade used
// to count as "open", so ESC could post closeMenu twice.
let menuOpen = false;

function openMenuEl() {
    menuOpen = true;
    document.getElementById('openmenu').style.display = 'block';
}

function menuIsOpen() {
    return menuOpen;
}

// Only while the menu is actually open -- with the drive-cursor (ALT) active
// the page also has focus, and ESC must not post a stray closeMenu then.
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && menuIsOpen()) closeMenu();
});

function closeMenu() {
    if (!menuOpen) return;
    menuOpen = false;
    document.getElementById('openmenu').style.display = 'none';
    $.post('https://aj-hud/closeMenu');
}

// ============================================================
// MONEY HUD
// ============================================================

const moneyHud = Vue.createApp({
    data() {
        return {
            cash: 0,
            bank: 0,
            amount: 0,
            plus: false,
            minus: false,
            showCash: false,
            showBank: false,
            showUpdate: false,
        };
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            switch (event.data.action) {
                case 'showconstant': this.showConstant(event.data); break;
                case 'updatemoney': this.update(event.data); break;
                case 'show': this.showAccounts(event.data); break;
            }
        });
    },
    methods: {
        showConstant(data) {
            this.showCash = true;
            this.showBank = true;
            this.cash = data.cash;
            this.bank = data.bank;
        },
        update(data) {
            this.showUpdate = true;
            this.amount = data.amount;
            this.bank = data.bank;
            this.cash = data.cash;
            this.minus = data.minus;
            this.plus = data.plus;
            if (data.type === 'cash') {
                this.showCash = true;
                if (data.minus) this.minus = true; else this.plus = true;
                setTimeout(() => (this.showUpdate = false), 1000);
                setTimeout(() => (this.showCash = false), 2000);
            }
            if (data.type === 'bank') {
                this.showBank = true;
                if (data.minus) this.minus = true; else this.plus = true;
                setTimeout(() => (this.showUpdate = false), 1000);
                setTimeout(() => (this.showBank = false), 2000);
            }
        },
        showAccounts(data) {
            if (data.type === 'cash' && !this.showCash) {
                this.showCash = true;
                this.cash = data.cash;
                setTimeout(() => (this.showCash = false), 3500);
            } else if (data.type === 'bank' && !this.showBank) {
                this.showBank = true;
                this.bank = data.bank;
                setTimeout(() => (this.showBank = false), 3500);
            }
        },
    },
}).mount('#money-container');

// ============================================================
// PLAYER HUD
// ============================================================

const playerHud = {
    data() {
        return {
            nos: 0,
            health: 0,
            playerDead: false,
            armor: 0,
            hunger: 0,
            thirst: 0,
            stress: 0,
            voice: 0,
            radio: 0,
            harness: false,
            nitroActive: false,
            cruise: false,
            parachute: -1,
            oxygen: 0,
            hp: 0,
            armed: false,
            speed: 0,
            engine: 100,
            dev: false,
            show: false,
            talking: false,
            showVoice: true,
            showHealth: false,
            showArmor: true,
            showHunger: true,
            showThirst: true,
            showNos: true,
            showStress: true,
            showOxygen: false,
            showArmed: true,
            showEngine: false,
            showCruise: false,
            showHarness: false,
            showParachute: false,
            showDev: false,
            voiceIcon: 'fas fa-microphone',
            talkingColor: 'var(--hud-color-talking-idle)',
            nosColor: 'var(--hud-color-nos-inactive)',
            engineColor: 'var(--hud-color-engine-ok)',
            armorColor: 'var(--hud-color-armor-ok)',
            hungerColor: 'var(--hud-color-hunger-ok)',
            healthColor: 'var(--hud-color-health-ok)',
            thirstColor: 'var(--hud-color-thirst-ok)',
            hungerCritical: false,
            thirstCritical: false,
        };
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            if (event.data.action === 'hudtick') this.hudTick(event.data);
        });
    },
    methods: {
        hudTick(data) {
            this.show = data.show;
            const pct = (v) => Math.max(0, Math.min(100, Number(v) || 0));
            this.health = pct(data.health);
            this.armor = pct(data.armor);
            this.hunger = pct(data.hunger);
            this.thirst = pct(data.thirst);
            this.stress = pct(data.stress);
            this.voice = data.voice;
            this.talking = data.talking;
            this.radio = data.radio;
            this.nos = Math.max(0, data.nos);
            this.oxygen = pct(data.oxygen);
            this.harness = !!data.harness;
            this.speed = data.speed;
            this.armed = !!data.armed;
            this.parachute = data.parachute;
            this.hp = data.hp * 5;
            this.engine = data.engine;
            this.dev = !!data.dev;
            this.playerDead = !!data.playerDead;

            this.showHealth = data.dynamicHealth ? data.health < 100 : true;
            this.healthColor = this.playerDead ? 'var(--hud-color-health-critical)' : 'var(--hud-color-health-ok)';
            if (this.playerDead) this.health = 100;

            this.showArmor = data.dynamicArmor ? data.armor !== 0 : true;
            this.armorColor = data.armor <= 0 ? 'var(--hud-color-armor-critical)' : 'var(--hud-color-armor-ok)';

            this.showHunger = data.dynamicHunger ? data.hunger < 100 : true;
            this.hungerColor = data.hunger <= HUD_THRESHOLDS.hunger.criticalBelow ? 'var(--hud-color-hunger-critical)' : 'var(--hud-color-hunger-ok)';

            this.showThirst = data.dynamicThirst ? data.thirst < 100 : true;
            this.thirstColor = data.thirst <= HUD_THRESHOLDS.thirst.criticalBelow ? 'var(--hud-color-thirst-critical)' : 'var(--hud-color-thirst-ok)';

            this.showStress = data.dynamicStress ? data.stress !== 0 : true;
            this.showOxygen = data.dynamicOxygen ? data.oxygen < 100 : true;

            if (data.dynamicEngine) {
                this.showEngine = data.engine >= 0 && data.engine < 95;
            } else {
                this.showEngine = data.engine >= 0;
            }
            if (data.engine <= 45) this.engineColor = 'var(--hud-color-engine-critical)';
            else if (data.engine <= 75) this.engineColor = 'var(--hud-color-engine-warn)';
            else this.engineColor = 'var(--hud-color-engine-ok)';

            if (data.dynamicNitro) {
                this.showNos = data.nos > 0;
            } else {
                this.showNos = data.nos >= 0;
            }
            this.nosColor = data.nitroActive ? 'var(--hud-color-nos-active)' : 'var(--hud-color-nos-inactive)';
            this.nitroActive = !!data.nitroActive;
            this.hungerCritical = data.hunger <= HUD_THRESHOLDS.hunger.criticalBelow;
            this.thirstCritical = data.thirst <= HUD_THRESHOLDS.thirst.criticalBelow;

            if (data.radioActive) this.talkingColor = 'var(--hud-color-talking-radio)';
            else if (data.talking) this.talkingColor = 'var(--hud-color-talking-active)';
            else this.talkingColor = 'var(--hud-color-talking-idle)';
            this.voiceIcon = data.radio ? 'fas fa-headset' : 'fas fa-microphone';

            this.showCruise = data.cruise === true;
            this.showHarness = data.harness === true;
            this.showArmed = data.armed === true;
            this.showParachute = data.parachute >= 0;
            this.showDev = data.dev === true;

            if (data.isPaused === 1) this.show = false;
        },
    },
};
const app2 = Vue.createApp(playerHud);
app2.mount('#ui-container');

// ============================================================
// VEHICLE HUD
// ============================================================

// SVG arc from angle a0 to a1 (degrees, clockwise from +x) around (cx, cy).
// `clockwise` false draws it the other way so pathLength-based fills grow
// from a0 -- used for the fuel arc, which fills bottom-up like NP's.
function svgArc(cx, cy, r, a0, a1, clockwise) {
    const rad = (a) => (a * Math.PI) / 180;
    const x0 = cx + r * Math.cos(rad(a0));
    const y0 = cy + r * Math.sin(rad(a0));
    const x1 = cx + r * Math.cos(rad(a1));
    const y1 = cy + r * Math.sin(rad(a1));
    const large = Math.abs(a1 - a0) > 180 ? 1 : 0;
    return `M ${x0.toFixed(2)} ${y0.toFixed(2)} A ${r} ${r} 0 ${large} ${clockwise ? 1 : 0} ${x1.toFixed(2)} ${y1.toFixed(2)}`;
}

const GAUGE_MAX_SPEED = 220;
const SPEED_ARC = svgArc(90, 100, 78, 135, 375, true); // 7:30 o'clock, over the top, to ~3:30
const FUEL_ARC = svgArc(90, 100, 92, 32, -32, false);  // short outer arc on the right, bottom -> top
const CARDINALS = [['N', 0], ['E', 90], ['S', 180], ['W', 270]];

const vehHud = {
    data() {
        return {
            altitude: 0,
            fuel: 0,
            speed: 0,
            gear: 0,
            heading: 0,
            unit: 'MPH',
            seatbelt: false,
            lightsOn: false,
            locked: false,
            engineOn: true,
            showHints: false,
            canLock: false,
            show: false,
            showAltitude: false,
            showSeatbelt: true,
            mapShape: 'circle',
            mapBorder: true,
            mapVisible: true,
            mapLetters: true,
            fuelColor: 'var(--hud-color-fuel-ok)',
            speedArc: SPEED_ARC,
            fuelArc: FUEL_ARC,
        };
    },
    computed: {
        speedPct() {
            return Math.max(0, Math.min(100, (this.speed / GAUGE_MAX_SPEED) * 100));
        },
        fuelPct() {
            return Math.max(0, Math.min(100, Number(this.fuel) || 0));
        },
        // GetVehicleCurrentGear: 0 = reverse; standing still reads as neutral.
        gearText() {
            if (!this.speed) return 'N';
            if (this.gear === 0) return 'R';
            return String(this.gear);
        },
        // "007" -> dim "00" + bright "7", like NP's zero-padded readout.
        speedDim() {
            const s = String(Math.min(999, Math.max(0, Math.round(this.speed))));
            return '0'.repeat(Math.max(0, 3 - s.length));
        },
        speedLit() {
            return String(Math.min(999, Math.max(0, Math.round(this.speed))));
        },
        // Radar rotates with the camera, so N sits at -heading on the ring.
        cardinals() {
            return CARDINALS.map(([label, base]) => {
                const a = ((base - this.heading) * Math.PI) / 180;
                return {
                    label,
                    style: {
                        left: (50 + 50 * Math.sin(a)).toFixed(2) + '%',
                        top: (50 - 50 * Math.cos(a)).toFixed(2) + '%',
                    },
                };
            });
        },
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            if (event.data.action === 'car') this.vehicleHud(event.data);
            else if (event.data.action === 'update' && event.data.value !== undefined) this.heading = Number(event.data.value) || 0;
            else if (event.data.action === 'theme' && event.data.unit) this.unit = event.data.unit;
        });
    },
    methods: {
        vehicleHud(data) {
            this.show = data.show;
            this.speed = data.speed || 0;
            this.altitude = data.altitude;
            this.fuel = data.fuel;
            this.gear = data.gear || 0;
            this.lightsOn = !!data.lightsOn;
            this.locked = !!data.locked;
            this.engineOn = data.engineOn !== false;
            this.showHints = !!data.showHints;
            this.canLock = !!data.canLock;
            this.seatbelt = data.seatbelt === true;
            this.showSeatbelt = data.showSeatbelt === true;
            this.showAltitude = data.showAltitude === true;
            if (data.mapShape) this.mapShape = data.mapShape;
            if (data.mapBorder !== undefined) this.mapBorder = data.mapBorder === true;
            if (data.mapVisible !== undefined) this.mapVisible = data.mapVisible === true;
            if (data.mapLetters !== undefined) this.mapLetters = data.mapLetters === true;

            if (data.fuel <= HUD_THRESHOLDS.fuel.criticalBelow) this.fuelColor = 'var(--hud-color-fuel-critical)';
            else if (data.fuel <= HUD_THRESHOLDS.fuel.warnBelow) this.fuelColor = 'var(--hud-color-fuel-warn)';
            else this.fuelColor = 'var(--hud-color-fuel-ok)';

            if (data.isPaused === 1) this.show = false;
        },
        toggleHeadlights() { $.post('https://aj-hud/toggleHeadlights'); },
        toggleSeatbelt() { $.post('https://aj-hud/toggleSeatbelt'); },
        toggleLock() { $.post('https://aj-hud/toggleLock'); },
    },
};
const app3 = Vue.createApp(vehHud);
app3.mount('#veh-container');

// ============================================================
// COMPASS HUD
// ============================================================

// Heading sits just above the minimap frame and zone/street just below it,
// both centered on it. The frame (.circle/.square, owned by the vehicle HUD
// app) is measured live because its position comes from tuned per-resolution
// CSS; when it isn't on screen, fall back to a fixed top-right spot.
function minimapFrameRect() {
    const el = document.querySelector('.border .circle') || document.querySelector('.border .square');
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 ? r : null;
}

const baseplateHud = {
    data() {
        return {
            show: false,
            heading: 0,
            street1: '',
            street2: '',
            zone: '',
            showCompass: true,
            showStreets: true,
            showPointer: true,
            showDegrees: true,
            frame: null,
        };
    },
    computed: {
        // "Compass degrees" on: 072°, off: the 8-point direction (NE).
        headingText() {
            const deg = ((Math.round(this.heading) % 360) + 360) % 360;
            if (this.showDegrees) return String(deg).padStart(3, '0') + '°';
            return ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][Math.round(deg / 45) % 8];
        },
        frameBox() {
            if (this.frame) return this.frame;
            const vh = window.innerHeight / 100;
            const w = 28 * vh;
            const right = window.innerWidth - 3.5 * vh;
            return { left: right - w, width: w, top: 4.5 * vh, bottom: 4.5 * vh + 23 * vh };
        },
        headingStyle() {
            const f = this.frameBox;
            const vh = window.innerHeight / 100;
            return { left: f.left + f.width / 2 + 'px', top: Math.max(0.5 * vh, f.top - 4 * vh) + 'px' };
        },
        locationStyle() {
            const f = this.frameBox;
            const vh = window.innerHeight / 100;
            return { left: f.left + f.width / 2 + 'px', top: f.bottom + 1.6 * vh + 'px' };
        },
    },
    destroyed() {
        window.removeEventListener('message', this.listener);
        clearInterval(this.frameTimer);
    },
    mounted() {
        this.listener = window.addEventListener('message', (event) => {
            if (event.data.action === 'update' && event.data.value !== undefined) {
                this.heading = Number(event.data.value) || 0;
            }
            if (event.data.action === 'baseplate') this.baseplateHud(event.data);
        });
        this.frameTimer = setInterval(() => this.measureFrame(), 500);
    },
    methods: {
        measureFrame() {
            const r = minimapFrameRect();
            const next = r ? { left: r.left, width: r.width, top: r.top, bottom: r.bottom } : null;
            if (JSON.stringify(next) !== JSON.stringify(this.frame)) this.frame = next;
        },
        baseplateHud(data) {
            this.show = data.show;
            this.street1 = data.street1;
            this.street2 = data.street2;
            this.zone = data.zone || '';
            this.showCompass = data.showCompass === true;
            this.showStreets = data.showStreets === true;
            this.showPointer = data.showPointer === true;
            this.showDegrees = data.showDegrees === true;
            this.measureFrame();
        },
    },
};
const app4 = Vue.createApp(baseplateHud);
app4.mount('#baseplate-container');
