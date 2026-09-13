/* Setup only. Run with macOS osascript, never as a resident input handler. */
var NativeInput = (function () {
    'use strict';
    var ABC = 'com.apple.keylayout.ABC';
    var KOREAN = 'com.apple.inputmethod.Korean.2SetKorean';
    var SOURCES = [ABC, KOREAN, 'com.apple.inputmethod.Korean'];
    var KEYS = 'dev.undervars.dotfiles.input-source-keys';
    var OWNERS = [
        KEYS, 'dev.undervars.dotfiles.input-source-switcher',
        'dev.undervars.dotfiles.input-source-cycle', 'org.nixos.UserKeyMapping'
    ];
    var HOTKEY = {enabled: true, value: {type: 'standard', parameters: [65535, 79, 8388608]}};
    function stable(value) {
        if (Array.isArray(value)) return value.map(stable);
        if (value && typeof value === 'object') {
            var result = {};
            Object.keys(value).sort().forEach(function (key) { result[key] = stable(value[key]); });
            return result;
        }
        return value;
    }
    function same(a, b) { return JSON.stringify(stable(a)) === JSON.stringify(stable(b)); }
    function sorted(a) { return a.slice().sort(); }
    function mapping(before) {
        return before.filter(function (row) {
            return row.HIDKeyboardModifierMappingSrc !== 0x7000000e7 &&
                !(row.HIDKeyboardModifierMappingSrc === 0x7000000e6 &&
                  row.HIDKeyboardModifierMappingDst === 0x70000006e);
        }).concat([{HIDKeyboardModifierMappingSrc: 0x7000000e7,
                    HIDKeyboardModifierMappingDst: 0x70000006d}]);
    }
    function hotkeys(before) {
        return {
            '60': Object.assign({}, before['60'] || {}, {enabled: false}),
            '61': HOTKEY
        };
    }
    function checks(state) {
        return {
            sources: same(sorted(state.sources), sorted(SOURCES)),
            selectedSource: [ABC, KOREAN].indexOf(state.selected) !== -1,
            rightCommand: same(state.mapping, mapping(state.mapping)),
            previousShortcutDisabled: !!state.hotkeys['60'] && state.hotkeys['60'].enabled === false,
            nextShortcutF18: same(state.hotkeys['61'], HOTKEY),
            loginMapping: state.agents[KEYS].loaded && state.mappingAgentMatches,
            oldSwitcherStopped: OWNERS.slice(1).every(function (label) {
                return !state.agents[label].loaded && state.agents[label].text === null;
            }),
            otherRemappersStopped: !state.karabiner && !state.hammerspoon && !state.fcitx,
            savedBackend: state.backend === 'native\n' && state.mode === 'ko-en\n'
        };
    }
    function all(check) { return Object.keys(check).every(function (k) { return check[k]; }); }
    function execute(action, sys) {
        if (action === 'status' || action === 'dry-run') {
            var observed = sys.capture();
            return {backend: 'native', mode: 'ko-en', action: action,
                checks: checks(observed), configured: all(checks(observed)),
                enabledSources: observed.sources, selectedSource: observed.selected,
                backup: sys.readBackup() !== null,
                changes: action === 'dry-run' ? {
                    sources: SOURCES, mapping: mapping(observed.mapping),
                    hotkeys: hotkeys(observed.hotkeys),
                    stop: OWNERS.slice(1).concat(observed.karabiner ? ['Karabiner user core'] : []),
                    login: KEYS, capsLock: 'unchanged', japaneseShortcut: 'none'
                } : undefined,
                reliability: 'Configuration checks do not prove error-free IME composition.'};
        }
        if (action !== 'apply' && action !== 'restore') throw new Error('Unknown action: ' + action);
        sys.assertSession();
        sys.lock();
        try {
            var backup = sys.readBackup();
            if (action === 'restore') {
                if (!backup) return {restored: true, changes: false};
                backup.phase = 'restoring'; sys.saveBackup(backup);
                sys.restore(backup.before);
                sys.finishRestore(backup);
                return {restored: true};
            }
            if (backup && backup.phase !== 'active') {
                throw new Error('An interrupted transaction exists. Run make input-sources-restore first.');
            }
            var before = sys.capture();
            sys.preflight(before);
            if (backup && all(checks(before))) {
                // Reassert on current HID services too, for a reconnected keyboard.
                sys.reapplyMapping(before.mapping);
                return {applied: true, unchanged: true, checks: checks(before)};
            }
            var original = backup;
            backup = backup || {version: 1, before: before};
            backup.phase = 'applying'; sys.saveBackup(backup);
            try {
                sys.stopOwners(before);
                sys.setSources(SOURCES, [ABC, KOREAN].indexOf(before.selected) === -1 ? ABC : before.selected);
                sys.setHotkeys(hotkeys(before.hotkeys));
                sys.installMapping(mapping(before.mapping));
                sys.saveMode('native\n', 'ko-en\n');
                var verified = checks(sys.capture());
                if (!all(verified)) throw new Error('Configuration verification failed: ' + JSON.stringify(verified));
                backup.phase = 'active'; sys.saveBackup(backup);
                return {applied: true, backend: 'native', mode: 'ko-en', checks: verified};
            } catch (error) {
                try {
                    sys.restore(before);
                    if (original) { original.phase = 'active'; sys.saveBackup(original); }
                    else sys.finishRestore(backup);
                } catch (restoreError) {
                    backup.phase = 'restore-needed'; sys.saveBackup(backup);
                    throw new Error(String(error) + '; rollback incomplete: ' + String(restoreError) +
                        '. Run make input-sources-restore.');
                }
                throw new Error(String(error) + '; previous configuration restored.');
            }
        } finally { sys.unlock(); }
    }
    return {ABC: ABC, KOREAN: KOREAN, SOURCES: SOURCES, KEYS: KEYS, OWNERS: OWNERS,
        HOTKEY: HOTKEY, mapping: mapping, hotkeys: hotkeys, checks: checks, all: all, same: same, execute: execute};
}());

function macRuntime() {
    'use strict';
    ObjC.import('Foundation');
    var fm = $.NSFileManager.defaultManager;
    var env = ObjC.deepUnwrap($.NSProcessInfo.processInfo.environment);
    var realHome = ObjC.unwrap($.NSHomeDirectory());
    var home = env.DOTFILES_HOME || realHome;
    var root = (env.DOTFILES_STATE_HOME || home + '/.local/state') + '/dotfiles/native-input';
    var backupPath = root + '/backup.json';
    var lockPath = root + '/lock';
    var config = home + '/.config/dotfiles/';
    var agents = home + '/Library/LaunchAgents/';
    var domain = 'gui/' + ObjC.unwrap($.NSUserName());
    var uid;
    var KARABINER = '/Library/Application Support/org.pqrs/Karabiner-Elements/' +
        'Karabiner-Elements Non-Privileged Agents v2.app/Contents/MacOS/Karabiner-Elements Non-Privileged Agents v2';
    var KARA_LABEL = 'org.pqrs.service.agent.Karabiner-Core-Service-rev2';
    function command(path, args) {
        var task = $.NSTask.alloc.init;
        task.launchPath = path; task.arguments = args;
        var pipe = $.NSPipe.pipe;
        task.standardOutput = pipe; task.standardError = pipe;
        task.launch;
        var data = pipe.fileHandleForReading.readDataToEndOfFile;
        task.waitUntilExit;
        return {code: task.terminationStatus,
            text: ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)) || ''};
    }
    function must(path, args) {
        var out = command(path, args);
        if (out.code !== 0) throw new Error(path + ': ' + out.text.trim());
        return out.text;
    }
    uid = must('/usr/bin/id', ['-u']).trim(); domain = 'gui/' + uid;
    function exists(path) { return fm.fileExistsAtPath(path); }
    function read(path) {
        if (!exists(path)) return null;
        var value = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
        if (value.isNil()) throw new Error('Cannot read ' + path);
        return ObjC.unwrap(value);
    }
    function mkdir(path) {
        if (!fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(path, true,
            $({NSFilePosixPermissions: 448}), null)) throw new Error('Cannot create ' + path);
    }
    function write(path, text) {
        if (text === null) { remove(path); return; }
        mkdir(path.slice(0, path.lastIndexOf('/')));
        if (!$(text).writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)) {
            throw new Error('Cannot write ' + path);
        }
        must('/bin/chmod', ['600', path]);
    }
    function remove(path) {
        if (exists(path) && !fm.removeItemAtPathError(path, null)) throw new Error('Cannot remove ' + path);
    }
    function parsePlist(text) {
        var data = $(text).dataUsingEncoding($.NSUTF8StringEncoding);
        var value = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 0, null, null);
        if (value.isNil()) throw new Error('Invalid property list');
        return ObjC.deepUnwrap(value);
    }
    function plist(value) {
        var data = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError($(value), 100, 0, null);
        if (data.isNil()) throw new Error('Cannot encode property list');
        return ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding));
    }
    function prefs() {
        var out = command('/usr/bin/defaults', ['export', 'com.apple.symbolichotkeys', '-']);
        if (out.code !== 0 && /does not exist|not found/.test(out.text)) return {};
        if (out.code !== 0) throw new Error(out.text);
        return parsePlist(out.text).AppleSymbolicHotKeys || {};
    }
    function getMapping() {
        var text = must('/usr/bin/hidutil', ['property', '--get', 'UserKeyMapping']).trim();
        if (text === '(null)') return [];
        var rows = parsePlist(text);
        if (!Array.isArray(rows)) throw new Error('Unknown hidutil mapping format');
        return rows.map(function (row) {
            return {HIDKeyboardModifierMappingSrc: Number(row.HIDKeyboardModifierMappingSrc),
                HIDKeyboardModifierMappingDst: Number(row.HIDKeyboardModifierMappingDst)};
        });
    }
    // Each short setup operation gets a new TIS client. TIS's process-local
    // source cache can remain stale even when its mutation has already succeeded.
    var args = ObjC.deepUnwrap($.NSProcessInfo.processInfo.arguments);
    var sourceScript = env.DOTFILES_NATIVE_SCRIPT || args[3];
    function sourceCommand(action, value) {
        if (!sourceScript || !exists(sourceScript)) throw new Error('Cannot locate the native setup script');
        var params = ['-l', 'JavaScript', sourceScript, '_source', action];
        if (value !== undefined) params.push(JSON.stringify(value));
        return JSON.parse(must('/usr/bin/osascript', params));
    }
    function sourceSnapshot() { return sourceCommand('list'); }
    function loaded(label) { return command('/bin/launchctl', ['print', domain + '/' + label]).code === 0; }
    function pids(name) {
        var out = command('/usr/bin/pgrep', ['-x', name]);
        if (out.code === 1) return [];
        if (out.code !== 0) throw new Error(out.text);
        return out.text.trim().split(/\s+/).map(function (id) {
            if (!/^\d+$/.test(id)) throw new Error('Invalid process ID');
            return id;
        });
    }
    function quit(name) {
        var ids = pids(name);
        if (ids.length) must('/bin/kill', ['-TERM'].concat(ids));
    }
    function waitFor(predicate, message) {
        for (var i = 0; i < 30; i++) {
            if (predicate()) return;
            $.NSThread.sleepForTimeInterval(0.1);
        }
        throw new Error(message);
    }
    function unload(label) {
        if (loaded(label)) must('/bin/launchctl', ['bootout', domain + '/' + label]);
    }
    function load(label) {
        if (loaded(label)) return;
        var out;
        for (var i = 0; i < 20; i++) {
            out = command('/bin/launchctl', ['bootstrap', domain, agents + label + '.plist']);
            if (out.code === 0 || loaded(label)) return;
            $.NSThread.sleepForTimeInterval(0.1);
        }
        throw new Error('Cannot load ' + label + ': ' + out.text);
    }
    function capture() {
        var input = sourceSnapshot();
        var state = {sources: input.sources.filter(function (s) { return s.enabled; }).map(function (s) { return s.id; }),
            selected: input.selected, mapping: getMapping(), hotkeys: prefs(), agents: {},
            backend: read(config + 'input-backend'), mode: read(config + 'input-mode'),
            karabiner: loaded(KARA_LABEL), karabinerUI: pids('Karabiner-Elements').length > 0,
            hammerspoon: pids('Hammerspoon').length > 0, fcitx: pids('Fcitx5').length > 0};
        NativeInput.OWNERS.forEach(function (label) {
            state.agents[label] = {loaded: loaded(label), text: read(agents + label + '.plist')};
        });
        var text = state.agents[NativeInput.KEYS].text;
        state.mappingAgentMatches = false;
        if (text !== null) {
            var job = parsePlist(text);
            state.mappingAgentMatches = job.RunAtLoad === true &&
                JSON.stringify(job.ProgramArguments) === JSON.stringify([
                    '/usr/bin/hidutil', 'property', '--set', JSON.stringify({UserKeyMapping: state.mapping})]);
        }
        return state;
    }
    function setSources(wanted, selected) {
        var catalog = sourceSnapshot().sources;
        wanted.forEach(function (id) {
            if (!catalog.some(function (s) { return s.id === id; })) throw new Error('Input source unavailable: ' + id);
        });
        catalog.sort(function (a, b) { return Number(a.selectable) - Number(b.selectable); });
        catalog.forEach(function (s) {
            if (wanted.indexOf(s.id) !== -1 && !s.enabled) sourceCommand('enable', s.id);
        });
        sourceCommand('select', selected);
        catalog = sourceSnapshot().sources;
        catalog.sort(function (a, b) { return Number(b.selectable) - Number(a.selectable); });
        catalog.forEach(function (s) {
            if (s.enabled && wanted.indexOf(s.id) === -1) sourceCommand('disable', s.id);
        });
        try {
            waitFor(function () {
                var state = sourceSnapshot();
                var ids = state.sources.filter(function (s) { return s.enabled; }).map(function (s) { return s.id; });
                return NativeInput.same(ids.sort(), wanted.slice().sort()) && state.selected === selected;
            }, 'Input sources did not update. Check Keyboard > Text Input > Edit for pending approval or a third-party source that must be removed there; rerun restore if recovering.');
        } catch (error) {
            var observed = sourceSnapshot();
            if (wanted.some(function (id) { return id.indexOf('com.apple.') !== 0; })) {
                // The enable consent can be waiting inside Settings without
                // bringing its window forward. Show the real macOS prompt.
                command('/usr/bin/open', ['x-apple.systempreferences:com.apple.Keyboard-Settings.extension']);
            }
            throw new Error(String(error) + ' Expected ' + JSON.stringify({sources: wanted, selected: selected}) +
                '; observed ' + JSON.stringify({sources: observed.sources.filter(function (s) {
                    return s.enabled;
                }).map(function (s) { return s.id; }), selected: observed.selected}));
        }
    }
    function setHotkeys(entries) {
        // Merge with a fresh read so unrelated shortcuts survive apply and restore.
        var now = prefs();
        ['60', '61'].forEach(function (key) {
            if (entries[key] === undefined) delete now[key];
            else now[key] = entries[key];
        });
        var xml = plist(now).replace(/^[\s\S]*?<plist[^>]*>/, '').replace(/<\/plist>[\s\S]*$/, '').trim();
        must('/usr/bin/defaults', ['write', 'com.apple.symbolichotkeys', 'AppleSymbolicHotKeys', xml]);
        must('/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings', ['-u']);
    }
    function stopOwners(before) {
        if (before.karabinerUI) quit('Karabiner-Elements');
        if (before.karabiner) must(KARABINER, ['unregister-core-agents']);
        NativeInput.OWNERS.forEach(function (label) { unload(label); remove(agents + label + '.plist'); });
        if (before.fcitx) quit('Fcitx5');
        waitFor(function () { return !loaded(KARA_LABEL) && !pids('Fcitx5').length; }, 'Old input process did not stop');
    }
    function installMapping(rows) {
        var args = ['/usr/bin/hidutil', 'property', '--set', JSON.stringify({UserKeyMapping: rows})];
        var job = {Label: NativeInput.KEYS, ProgramArguments: args, RunAtLoad: true,
            LimitLoadToSessionType: 'Aqua', ProcessType: 'Background'};
        write(agents + NativeInput.KEYS + '.plist', plist(job));
        must('/bin/chmod', ['644', agents + NativeInput.KEYS + '.plist']);
        load(NativeInput.KEYS);
        must(args[0], args.slice(1));
    }
    function saveMode(backend, mode) { write(config + 'input-backend', backend); write(config + 'input-mode', mode); }
    function restore(before) {
        var problems = [];
        function attempt(name, fn) {
            try { fn(); } catch (error) { problems.push(name + ': ' + String(error)); }
        }
        NativeInput.OWNERS.forEach(function (label) { attempt(label, function () { unload(label); }); });
        // Restore sources first. In particular macOS can require user consent to
        // re-enable an old third-party IME; retain the transaction until verified.
        attempt('sources', function () {
            if (before.fcitx) must('/usr/bin/open', ['-g', '-a', '/Library/Input Methods/Fcitx5.app']);
            setSources(before.sources, before.selected);
        });
        attempt('hotkeys', function () { setHotkeys(before.hotkeys); });
        NativeInput.OWNERS.forEach(function (label) {
            attempt(label, function () { write(agents + label + '.plist', before.agents[label].text); });
        });
        attempt('mapping', function () {
            must('/usr/bin/hidutil', ['property', '--set', JSON.stringify({UserKeyMapping: before.mapping})]);
        });
        NativeInput.OWNERS.forEach(function (label) {
            if (before.agents[label].loaded) attempt(label, function () { load(label); });
        });
        attempt('Karabiner', function () {
            if (before.karabiner && !loaded(KARA_LABEL)) must(KARABINER, ['register-core-agents']);
            if (before.karabinerUI) must('/usr/bin/open', ['-g', '-a', 'Karabiner-Elements']);
        });
        attempt('mode', function () { saveMode(before.backend, before.mode); });
        var after = capture();
        ['60', '61'].forEach(function (key) {
            if (!NativeInput.same(after.hotkeys[key], before.hotkeys[key])) problems.push('hotkey ' + key);
        });
        ['mapping', 'backend', 'mode', 'agents', 'karabiner'].forEach(function (key) {
            if (!NativeInput.same(after[key], before[key])) problems.push(key);
        });
        if (problems.length) throw new Error('Restore verification failed: ' + problems.join(', '));
    }
    return {
        capture: capture,
        assertSession: function () {
            if (home !== realHome || uid === '0' || must('/usr/bin/stat', ['-f', '%u', '/dev/console']).trim() !== uid) {
                throw new Error('Apply/restore must run as the logged-in Mac user, without sudo or a different DOTFILES_HOME.');
            }
        },
        preflight: function (state) {
            var available = sourceSnapshot().sources.map(function (s) { return s.id; });
            NativeInput.SOURCES.forEach(function (id) {
                if (available.indexOf(id) === -1) throw new Error('Input source unavailable: ' + id);
            });
            if (state.hammerspoon) throw new Error('Quit Hammerspoon and disable its automatic launch before applying.');
            if (state.karabiner && !exists(KARABINER)) throw new Error('Quit the existing Karabiner installation before applying.');
            ['input-clean-baseline/active-path', 'input-native-cycle/active-path', 'input-karabiner-cycle/active-path',
                'input-lab/active.json', 'input-global/active.json'].forEach(function (path) {
                if (exists(home + '/.local/state/dotfiles/' + path)) throw new Error('Finish the active input trial first: ' + path);
            });
        },
        lock: function () {
            mkdir(root);
            if (exists(lockPath)) {
                var owner = read(lockPath + '/pid');
                if (!owner || !/^\d+\n?$/.test(owner) || command('/bin/kill', ['-0', owner.trim()]).code === 0) {
                    throw new Error('Another native input setup is running or the setup lock needs inspection: ' + lockPath);
                }
                remove(lockPath);
            }
            if (!fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(lockPath, false,
                $({NSFilePosixPermissions: 448}), null)) {
                throw new Error('Another native input setup acquired the lock');
            }
            write(lockPath + '/pid', String($.NSProcessInfo.processInfo.processIdentifier) + '\n');
        },
        unlock: function () { remove(lockPath); },
        readBackup: function () { var text = read(backupPath); return text === null ? null : JSON.parse(text); },
        saveBackup: function (value) { write(backupPath, JSON.stringify(value, null, 2) + '\n'); },
        finishRestore: function (value) { write(root + '/last-restore.json', JSON.stringify(value, null, 2) + '\n'); remove(backupPath); },
        stopOwners: stopOwners, setSources: setSources, setHotkeys: setHotkeys,
        reapplyMapping: function (rows) {
            must('/usr/bin/hidutil', ['property', '--set', JSON.stringify({UserKeyMapping: rows})]);
        },
        installMapping: installMapping, saveMode: saveMode, restore: restore
    };
}

function sourceAccess(argv) {
    ObjC.import('Foundation'); ObjC.import('Carbon');
    ObjC.bindFunction('TISGetInputSourceProperty', ['id', ['void *', 'void *']]);
    ['TISEnableInputSource', 'TISDisableInputSource', 'TISSelectInputSource'].forEach(function (name) {
        ObjC.bindFunction(name, ['int', ['void *']]);
    });
    ObjC.bindFunction('TISCopyCurrentKeyboardInputSource', ['void *', []]);
    function property(source, key) { return ObjC.unwrap($.TISGetInputSourceProperty(source, key)); }
    // An installed input mode may have IsEnabled=true while its parent IME is
    // disabled. Only the non-includeAll list represents usable active sources.
    var active = $.TISCreateInputSourceList(null, false);
    var activeIDs = [];
    for (var n = 0; n < $.CFArrayGetCount(active); n++) {
        var item = $.CFArrayGetValueAtIndex(active, n);
        activeIDs.push(property(item, $.kTISPropertyInputSourceID));
    }
    var list = $.TISCreateInputSourceList(null, true);
    var rows = [];
    for (var i = 0; i < $.CFArrayGetCount(list); i++) {
        var source = $.CFArrayGetValueAtIndex(list, i);
        if (property(source, $.kTISPropertyInputSourceCategory) !== 'TISCategoryKeyboardInputSource') continue;
        var id = property(source, $.kTISPropertyInputSourceID);
        rows.push({ref: source, id: id,
            enabled: activeIDs.indexOf(id) !== -1,
            selectable: !!property(source, $.kTISPropertyInputSourceIsSelectCapable)});
    }
    var selected = property($.TISCopyCurrentKeyboardInputSource(), $.kTISPropertyInputSourceID);
    if (argv.length === 1 && argv[0] === 'list') {
        return {selected: selected, sources: rows.map(function (s) {
            return {id: s.id, enabled: s.enabled, selectable: s.selectable};
        })};
    }
    if (argv.length !== 2) throw new Error('Invalid source operation');
    var value = JSON.parse(argv[1]);
    var changed = [];
    if (argv[0] === 'select') {
        var target = rows.filter(function (s) { return s.id === value && s.selectable; })[0];
        if (!target) throw new Error('Input source unavailable: ' + value);
        if (selected !== value && $.TISSelectInputSource(target.ref) !== 0) throw new Error('Cannot select ' + value);
        return {requested: value};
    }
    if (typeof value !== 'string') throw new Error('Expected one input-source ID');
    var sourceRow = rows.filter(function (s) { return s.id === value; })[0];
    if (!sourceRow) throw new Error('Input source unavailable: ' + value);
    // One mutation per process avoids reusing a stale TIS client for another
    // change to the enabled-source list.
    if (argv[0] === 'enable') {
        if (!sourceRow.enabled) {
            if ($.TISEnableInputSource(sourceRow.ref) !== 0) throw new Error('Cannot enable ' + value);
            changed.push(value);
        }
    } else if (argv[0] === 'disable') {
        if (sourceRow.enabled) {
            if ($.TISDisableInputSource(sourceRow.ref) !== 0) throw new Error('Cannot disable ' + value);
            changed.push(value);
        }
    } else throw new Error('Unknown source operation');
    return {changed: changed};
}

function run(argv) {
    if (argv[0] === '_source') return JSON.stringify(sourceAccess(argv.slice(1)));
    if (argv.length !== 1) throw new Error('Expected apply, dry-run, status, or restore');
    return JSON.stringify(NativeInput.execute(argv[0], macRuntime()), null, 2);
}
if (typeof module !== 'undefined') module.exports = NativeInput;
