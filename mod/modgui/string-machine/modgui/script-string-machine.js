/*
 * String machine -- MOD modgui script
 *
 *  - draws the AHDSR envelope (same model as sources/dsp/AHDSREnvelope.cpp,
 *    same plot recipe as StringMachineUI::computeAdsrPlot);
 *  - shows the monitored output ports (see modgui:monitoredOutputs in
 *    modgui.ttl): LFO lights, output VU meters, live oscillator detune.
 *
 * mod-ui calls this function with event.type 'start' (all current port
 * values) and then 'change' for every input or monitored output change.
 * State is kept in event.data, which mod-ui preserves between calls.
 */
function (event, funcs) {

    var ENV_PORTS = {
        env_attack:  'attack',
        env_hold:    'hold',
        env_decay:   'decay',
        env_sustain: 'sustain',
        env_release: 'release'
    }

    // same mapping as the desktop UI: -20 dB .. 0 dB over the 31 VU frames
    var VU_MIN_DB = -20.0, VU_MAX_DB = 0.0, VU_FRAMES = 31, VU_FRAME_W = 190

    function envPlot(canvas, env) {
        var w = canvas.clientWidth || 790, h = canvas.clientHeight || 260
        var ratio = 2
        if (canvas.width !== w * ratio || canvas.height !== h * ratio) {
            canvas.width = w * ratio
            canvas.height = h * ratio
        }
        var ctx = canvas.getContext('2d')
        ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
        ctx.clearRect(0, 0, w, h)

        // simulate the envelope on a time base sized to show all segments
        var keyOnTime = env.attack + env.hold + env.decay
        var nonSustainTime = keyOnTime + Math.min(env.release, 1.0)
        var totalTime = nonSustainTime * 1.25
        var n = Math.max(2, Math.round(w))
        var sr = n / totalTime
        var dt = 1.0 / sr
        var kt = 1.0 / 2.2
        var ar = env.attack  > 0 ? Math.exp(-dt / (kt * env.attack))  : 0
        var dr = env.decay   > 0 ? Math.exp(-dt / (kt * env.decay))   : 0
        var rr = env.release > 0 ? Math.exp(-dt / (kt * env.release)) : 0
        var hf = env.hold > 0 ? Math.round(sr * env.hold) : 0
        var sl = Math.pow(10, 0.05 * env.sustain)
        var keyOn = Math.round(keyOnTime * sr)

        var stage = 0, level = 0, counter = 0, data = new Array(n)
        for (var i = 0; i < n; ++i) {
            if (i === keyOn)
                stage = 4
            switch (stage) {
            case 0: // attack
                if (level < 1) { level = ar * level + (1 - ar) * 1.1; break }
                stage = 1; counter = 0
                // fall through
            case 1: // hold
                if (counter++ < hf) break
                stage = 2
                // fall through
            case 2: // decay
            case 3: // sustain
                level = dr * level + (1 - dr) * sl
                break
            case 4: // release
                level = rr * level
                break
            }
            data[i] = level * 0.9
        }

        // grid
        ctx.strokeStyle = 'rgba(189, 188, 181, 0.18)'
        ctx.lineWidth = 1
        for (var g = 1; g < 4; ++g) {
            var gy = Math.round(h * g / 4) + 0.5
            ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke()
        }
        // key release marker
        var kx = Math.round(keyOn / n * w) + 0.5
        ctx.setLineDash([4, 4])
        ctx.beginPath(); ctx.moveTo(kx, 0); ctx.lineTo(kx, h); ctx.stroke()
        ctx.setLineDash([])

        // curve
        var pad = 6
        ctx.beginPath()
        for (var j = 0; j < n; ++j) {
            var x = j / (n - 1) * w
            var y = pad + (1 - Math.min(1, Math.max(0, data[j]))) * (h - 2 * pad)
            if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath()
        ctx.fillStyle = 'rgba(255, 126, 0, 0.25)'
        ctx.fill()
        ctx.beginPath()
        for (var k = 0; k < n; ++k) {
            var x2 = k / (n - 1) * w
            var y2 = pad + (1 - Math.min(1, Math.max(0, data[k]))) * (h - 2 * pad)
            if (k === 0) ctx.moveTo(x2, y2); else ctx.lineTo(x2, y2)
        }
        ctx.strokeStyle = '#ff7e00'
        ctx.lineWidth = 2
        ctx.stroke()
    }

    function setOutput(icon, symbol, value) {
        var el = icon.find('[data-sm-out="' + symbol + '"]')
        if (!el.length)
            return
        switch (symbol) {
        case 'cho_current_phase1':
        case 'cho_current_phase2':
            el.toggleClass('on', value > Math.PI)
            break
        case 'master_current_level1':
        case 'master_current_level2':
            var t = (value - VU_MIN_DB) / (VU_MAX_DB - VU_MIN_DB)
            var frame = Math.round(Math.min(1, Math.max(0, t)) * (VU_FRAMES - 1))
            el.css('background-position', (-frame * VU_FRAME_W) + 'px 0')
            break
        case 'osc_current_detune_upper':
        case 'osc_current_detune_lower':
            el.text(Math.abs(value).toFixed(2))
            break
        }
    }

    function handle(symbol, value) {
        if (ENV_PORTS.hasOwnProperty(symbol)) {
            event.data.env[ENV_PORTS[symbol]] = value
            var canvas = event.icon.find('.sm-env-plot')[0]
            if (canvas)
                envPlot(canvas, event.data.env)
            return
        }
        setOutput(event.icon, symbol, value)
    }

    if (event.type === 'start') {
        // defaults from StringMachineShared.cpp, overwritten by the ports below
        event.data.env = { attack: 0.1939, hold: 0.01, decay: 10.0, sustain: 0.0, release: 3.0 }
        var ports = event.ports || []
        for (var p = 0; p < ports.length; ++p) {
            if (ENV_PORTS.hasOwnProperty(ports[p].symbol))
                event.data.env[ENV_PORTS[ports[p].symbol]] = ports[p].value
            else
                setOutput(event.icon, ports[p].symbol, ports[p].value)
        }
        var canvas = event.icon.find('.sm-env-plot')[0]
        if (canvas) {
            envPlot(canvas, event.data.env)
            // the icon may be laid out after 'start': redraw once it has a size
            setTimeout(function () { envPlot(canvas, event.data.env) }, 250)
        }
    }
    else if (event.type === 'change' && event.symbol) {
        handle(event.symbol, event.value)
    }
}
