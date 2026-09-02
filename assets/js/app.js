// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/fitzyo"
import {WebMcp as WebMcpCore} from "ash_web_mcp/assets/js/web_mcp"
import topbar from "../vendor/topbar"

// FitzYo wraps the ash_web_mcp transport hook so the LiveView can show
// whether an agent is actually attached (native modelContext) or whether the
// page is waiting on the postMessage bridge.
// Tools that legitimately wait on a person get a longer client timeout than
// the transport's default 15s; ask_human may block up to its own timeout_ms.
const LONG_CALL_TIMEOUT_MS = {ask_human: 610000}

const WebMcp = {
  ...WebMcpCore,
  dispatchCall(toolName, input, signal) {
    const timeoutMs = LONG_CALL_TIMEOUT_MS[toolName]
    if (!timeoutMs) return WebMcpCore.dispatchCall.call(this, toolName, input, signal)
    if (this.localTools[toolName]) return this.localTools[toolName](input)
    return new Promise((resolve, reject) => {
      const id = ++this.callSeq
      this.pending.set(id, {resolve, reject})
      this.pushEvent("webmcp:call", {id, tool: toolName, input})
      const timer = setTimeout(() => {
        if (this.pending.has(id)) { this.pending.delete(id); reject(new Error("WebMCP call timed out")) }
      }, timeoutMs)
      if (signal) signal.addEventListener("abort", () => {
        if (this.pending.has(id)) { this.pending.delete(id); clearTimeout(timer); reject(new DOMException("WebMCP call aborted", "AbortError")) }
      })
    })
  },
  mounted() {
    WebMcpCore.mounted.call(this)
    let reported = null
    const report = () => {
      if (this.native !== reported) {
        reported = this.native
        this.pushEvent("webmcp:transport", {native: !!this.native, tools: this.wireTools.length})
      }
    }
    report()
    this.transportWatch = setInterval(report, 1000)
  },
  destroyed() {
    clearInterval(this.transportWatch)
    WebMcpCore.destroyed.call(this)
  },
}

// Scrolls a semantic element into view and flashes a highlight when an agent
// calls focus_product / focus_filter (or when the cart badge changes).
// Keeps the agent feed pinned to its newest entry, like a terminal.
const FzAutoScroll = {
  mounted() { this.scroll() },
  updated() { this.scroll() },
  scroll() { this.el.scrollTop = this.el.scrollHeight },
}

// Press-and-hold approval for checkout. Only trusted pointer/keyboard input
// (event.isTrusted) held for the full duration sends `confirm_checkout`, and
// it carries the nonce the server issued when the review opened. A synthetic
// `.click()` never reaches the server. (Trusted input from a browser
// automation protocol still counts as a person at the keyboard; this is a
// gesture, not cryptography.)
const FzHoldToConfirm = {
  mounted() {
    this.holdMs = parseInt(this.el.dataset.holdMs || "700", 10)
    this.nonce = null
    this.fill = this.el.querySelector("[data-hold-fill]")
    this.handleEvent("fz:checkout_nonce", ({nonce}) => { this.nonce = nonce })

    const start = (e) => {
      if (!e.isTrusted || this.timer) return
      if (e.type === "keydown" && e.key !== "Enter" && e.key !== " ") return
      if (e.type === "keydown" && e.repeat) return
      e.preventDefault()
      this.startedAt = performance.now()
      this.el.classList.add("fz-holding")
      this.tick = setInterval(() => {
        const pct = Math.min(100, ((performance.now() - this.startedAt) / this.holdMs) * 100)
        if (this.fill) this.fill.style.width = `${pct}%`
      }, 40)
      this.timer = setTimeout(() => {
        const held = Math.round(performance.now() - this.startedAt)
        cancel()
        this.pushEvent("confirm_checkout", {nonce: this.nonce, held_ms: held, trusted: e.isTrusted})
      }, this.holdMs)
    }
    const cancel = () => {
      clearTimeout(this.timer); clearInterval(this.tick)
      this.timer = null; this.tick = null
      this.el.classList.remove("fz-holding")
      if (this.fill) this.fill.style.width = "0%"
    }
    this.el.addEventListener("pointerdown", start)
    this.el.addEventListener("keydown", start)
    for (const ev of ["pointerup", "pointerleave", "pointercancel", "keyup", "blur"]) this.el.addEventListener(ev, cancel)
    // A plain click (synthetic or real) must not place the order.
    this.el.addEventListener("click", (e) => e.preventDefault())
  },
}

const FzFocus = {
  mounted() {
    this.handleEvent("fz:focus", ({id}) => {
      const el = document.getElementById(id)
      if (!el) return
      el.scrollIntoView({behavior: "smooth", block: "center", inline: "nearest"})
      const target = el.querySelector("[autofocus]")
      if (target) setTimeout(() => target.focus({preventScroll: true}), 150)
      el.classList.remove("fz-focus-ring")
      void el.offsetWidth
      el.classList.add("fz-focus-ring")
      setTimeout(() => el.classList.remove("fz-focus-ring"), 2200)
    })
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, WebMcp, FzFocus, FzAutoScroll, FzHoldToConfirm},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

