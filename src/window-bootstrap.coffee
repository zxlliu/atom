startTime = Date.now()

require './window'

Atom = require './atom'
window.atom = Atom.loadOrCreate('editor')
atom.initialize()
require('./exports')
atom.startEditorWindow()
window.atom.loadTime = Date.now() - startTime
console.log "Window load time: #{atom.getWindowLoadTime()}ms"

# s = Date.now()
# start = require('../slug2.js')
# console.log Date.now() - s
# start()
# console.log Date.now() - s
