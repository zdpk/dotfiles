const {test} = require('node:test');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const input = require('../scripts/macos/native-input.js');
const copy = value => JSON.parse(JSON.stringify(value));

function fixture() {
    const state = {
        sources: [...input.SOURCES, 'Japanese', 'Fcitx'], selected: 'Japanese',
        mapping: [
            {HIDKeyboardModifierMappingSrc: 0x700000039, HIDKeyboardModifierMappingDst: 0x7000000e0},
            {HIDKeyboardModifierMappingSrc: 0x7000000e7, HIDKeyboardModifierMappingDst: 0x700000039},
            {HIDKeyboardModifierMappingSrc: 0x7000000e6, HIDKeyboardModifierMappingDst: 0x70000006e}
        ],
        hotkeys: {'61': {enabled: false}, '64': {enabled: true, value: 'user Spotlight shortcut'}},
        agents: Object.fromEntries(input.OWNERS.map(label => [label, {loaded: true, text: label}])),
        backend: null, mode: 'ko-en-ja\n', karabiner: true, hammerspoon: false, fcitx: true,
        mappingAgentMatches: false
    };
    return {
        state, backup: null, mutations: [], locked: false,
        capture() { return copy(this.state); },
        assertSession() {},
        preflight() { if (this.state.hammerspoon) throw Error('Conflicting remapper'); },
        readBackup() { return this.backup && copy(this.backup); },
        saveBackup(value) { this.backup = copy(value); },
        finishRestore() { this.backup = null; },
        lock() { assert.equal(this.locked, false); this.locked = true; },
        unlock() { this.locked = false; },
        stopOwners() {
            this.mutations.push('stop');
            this.state.karabiner = false; this.state.fcitx = false;
            for (const label of input.OWNERS) this.state.agents[label] = {loaded: false, text: null};
        },
        setSources(ids, selected) { this.state.sources = copy(ids); this.state.selected = selected; },
        setHotkeys(value) { this.state.hotkeys = {...this.state.hotkeys, ...copy(value)}; },
        reapplyMapping(rows) { assert.deepEqual(rows, this.state.mapping); this.reassertions = (this.reassertions || 0) + 1; },
        installMapping(rows) {
            this.state.mapping = copy(rows);
            this.state.agents[input.KEYS] = {loaded: true, text: 'one-shot hidutil job'};
            this.state.mappingAgentMatches = true;
        },
        saveMode(backend, mode) { this.state.backend = backend; this.state.mode = mode; },
        restore(before) { this.mutations.push('restore'); this.state = copy(before); }
    };
}

test('native install disables Japanese and old owners, preserving unrelated mappings and shortcuts', () => {
    const sys = fixture(); const before = copy(sys.state);
    const result = input.execute('apply', sys);
    assert.equal(result.applied, true);
    assert.ok(Object.values(result.checks).every(Boolean));
    assert.deepEqual(sys.state.sources.slice().sort(), input.SOURCES.slice().sort());
    assert.equal(sys.state.selected, input.ABC);
    assert.deepEqual(sys.state.mapping, [before.mapping[0], {
        HIDKeyboardModifierMappingSrc: 0x7000000e7, HIDKeyboardModifierMappingDst: 0x70000006d
    }]);
    assert.deepEqual(sys.state.hotkeys['64'], before.hotkeys['64']);
    assert.deepEqual(sys.backup.before, before);
    assert.equal(sys.locked, false);
});

test('repeated apply does not reload services or overwrite the original Japanese profile backup', () => {
    const sys = fixture(); input.execute('apply', sys);
    const backup = copy(sys.backup); const mutations = sys.mutations.length;
    assert.equal(input.execute('apply', sys).unchanged, true);
    assert.deepEqual(sys.backup, backup);
    assert.equal(sys.mutations.length, mutations);
    assert.equal(sys.reassertions, 1);
});

test('restore after repeated apply recovers missing preference entries and previous node mode', () => {
    const sys = fixture(); const before = copy(sys.state);
    input.execute('apply', sys); input.execute('apply', sys);
    assert.equal(input.execute('restore', sys).restored, true);
    assert.deepEqual(sys.state, before);
    assert.equal(sys.backup, null);
    assert.equal(input.execute('restore', sys).changes, false);
});

test('failed source setup rolls back before reporting failure', () => {
    const sys = fixture(); const before = copy(sys.state);
    sys.setSources = function () { this.state.sources = [input.ABC]; throw Error('enable denied'); };
    assert.throws(() => input.execute('apply', sys), /previous configuration restored/);
    assert.deepEqual(sys.state, before);
    assert.equal(sys.backup, null);
    assert.equal(sys.locked, false);
});

test('an incomplete rollback preserves recovery data and blocks another apply', () => {
    const sys = fixture(); const original = copy(sys.state);
    sys.setSources = () => { throw Error('source failed'); };
    sys.restore = () => { throw Error('IME consent pending'); };
    assert.throws(() => input.execute('apply', sys), /rollback incomplete/);
    assert.equal(sys.backup.phase, 'restore-needed');
    assert.deepEqual(sys.backup.before, original);
    assert.throws(() => input.execute('apply', sys), /interrupted transaction/);
    assert.equal(sys.locked, false);
});

test('failed repair returns to the installed native configuration and preserves the original backup', () => {
    const sys = fixture(); input.execute('apply', sys);
    const backup = copy(sys.backup);
    sys.state.hotkeys['61'].enabled = false;
    const beforeRepair = copy(sys.state);
    sys.installMapping = () => { throw Error('launchd failed'); };
    assert.throws(() => input.execute('apply', sys), /previous configuration restored/);
    assert.deepEqual(sys.state, beforeRepair);
    assert.deepEqual(sys.backup, backup);
});

test('a setting that fails readback does not report successful installation', () => {
    const sys = fixture(); const original = copy(sys.state);
    sys.setHotkeys = () => {};
    assert.throws(() => input.execute('apply', sys), /Configuration verification failed/);
    assert.deepEqual(sys.state, original);
});

test('dry run and status never mutate the source list, files, jobs, or backup', () => {
    const sys = fixture(); const before = copy(sys.state);
    assert.equal(input.execute('dry-run', sys).changes.capsLock, 'unchanged');
    assert.equal(input.execute('status', sys).configured, false);
    assert.deepEqual(sys.state, before);
    assert.equal(sys.backup, null);
    assert.deepEqual(sys.mutations, []);
});

test('a conflicting remapper fails before taking a backup or stopping any owner', () => {
    const sys = fixture(); sys.state.hammerspoon = true;
    assert.throws(() => input.execute('apply', sys), /Conflicting remapper/);
    assert.equal(sys.backup, null);
    assert.deepEqual(sys.mutations, []);
    assert.equal(sys.locked, false);
});

test('plist dictionary key ordering does not cause false verification failures', () => {
    const sys = fixture(); input.execute('apply', sys);
    sys.state.hotkeys['61'] = {value: {parameters: [65535, 79, 8388608], type: 'standard'}, enabled: true};
    assert.equal(input.execute('status', sys).configured, true);
});

test('fresh native selection ignores an old saved Japanese mode; explicit Japanese requires helper', () => {
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'dotfiles-native-mode-'));
    try {
        fs.mkdirSync(path.join(temp, '.config/dotfiles'), {recursive: true});
        fs.writeFileSync(path.join(temp, '.config/dotfiles/input-mode'), 'ko-en-ja\n');
        const script = 'source "$1/lib/common.sh"; resolve_input_backend; resolve_input_mode';
        const env = {...process.env, DOTFILES_HOME: temp};
        delete env.DOTFILES_INPUT_MODE; delete env.DOTFILES_INPUT_BACKEND;
        const root = path.resolve(__dirname, '..');
        const resolve = more => execFileSync('/bin/bash', ['-c', script, 'test', root],
            {env: {...env, ...more}, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']});
        assert.equal(resolve({}), 'native\nko-en\n');
        assert.equal(resolve({DOTFILES_INPUT_BACKEND: 'helper'}), 'helper\nko-en-ja\n');
        assert.throws(() => resolve({DOTFILES_INPUT_MODE: 'ko-en-ja'}), /native input supports only ko-en/);
        fs.writeFileSync(path.join(temp, '.config/dotfiles/input-backend'), 'native\n');
        assert.equal(resolve({}), 'native\nko-en\n');
    } finally { fs.rmSync(temp, {recursive: true, force: true}); }
});
