React = require 'react-atom-fork'
{div} = require 'reactionary-atom-fork'
{isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
SubscriberMixin = require './subscriber-mixin'

WrapperDiv = document.createElement('div')
Nbsp = String.fromCharCode(160)

module.exports =
GutterComponent = React.createClass
  displayName: 'GutterComponent'
  mixins: [SubscriberMixin]

  lastMeasuredWidth: null
  wrapCountsByScreenRow: null

  render: ->
    {scrollHeight, scrollTop} = @props

    style =
      height: scrollHeight
      WebkitTransform: "translate3d(0px, #{-scrollTop}px, 0px)"

    div className: 'gutter',
      div className: 'line-numbers', ref: 'lineNumbers', style: style,
        @renderDummyLineNode()
        @renderLineNumbers() if @isMounted()

  renderDummyLineNode: ->
    {editor} = @props
    @renderLineNumber('dummy', null, editor.getLastBufferRow(), false)

  renderLineNumbers: ->
    {editor, renderedRowRange, maxLineNumberDigits, lineHeightInPixels, mouseWheelScreenRow} = @props
    [startRow, endRow] = renderedRowRange

    lastBufferRow = null
    wrapCount = 0

    wrapCountsByScreenRow = {}
    lineNumberComponents =
      for bufferRow, i in editor.bufferRowsForScreenRows(startRow, endRow - 1)
        if bufferRow is lastBufferRow
          softWrapped = true
          key = "#{bufferRow}-#{++wrapCount}"
        else
          softWrapped = false
          key = bufferRow.toString()
          lastBufferRow = bufferRow
          wrapCount = 0

        screenRow = startRow + i
        wrapCountsByScreenRow[screenRow] = wrapCount
        @renderLineNumber(key, screenRow, bufferRow, softWrapped)

    # Preserve the mouse wheel target's screen row if it exists
    if mouseWheelScreenRow? and not (startRow <= mouseWheelScreenRow < endRow)
      screenRow = mouseWheelScreenRow
      bufferRow = editor.bufferRowForScreenRow(screenRow)
      wrapCount = @wrapCountsByScreenRow[screenRow]
      wrapCountsByScreenRow[screenRow] = wrapCount
      if softWrapped = (wrapCount > 0)
        key = "#{bufferRow}-#{wrapCount}"
      else
        key = bufferRow.toString()

      lineNumberComponents.push(@renderLineNumber(key, screenRow, bufferRow, false, endRow))

    @wrapCountsByScreenRow = wrapCountsByScreenRow
    lineNumberComponents

  renderLineNumber: (key, screenRow, bufferRow, softWrapped, screenRowOverride) ->
    {lineHeightInPixels, maxLineNumberDigits} = @props

    if screenRow?
      style =
        position: 'absolute'
        top: (screenRowOverride ? screenRow) * lineHeightInPixels
    else
      style =
        visibility: 'hidden'

    if softWrapped
      lineNumber = "•"
    else
      lineNumber = (bufferRow + 1).toString()

    if lineNumber.length < maxLineNumberDigits
      padding = multiplyString(Nbsp, maxLineNumberDigits - lineNumber.length)
      lineNumber = padding + lineNumber

    div key: key, className: 'line-number', 'data-screen-row': screenRow, style: style,
      lineNumber,
      div className: 'icon-right'

  # Only update the gutter if the visible row range has changed or if a
  # non-zero-delta change to the screen lines has occurred within the current
  # visible row range.
  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props, 'renderedRowRange', 'scrollTop', 'lineHeightInPixels', 'fontSize', 'maxLineNumberDigits', 'mouseWheelScreenRow')

    {renderedRowRange, pendingChanges} = newProps
    for change in pendingChanges when Math.abs(change.screenDelta) > 0 or Math.abs(change.bufferDelta) > 0
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (oldProps) ->
    @measureWidth() unless @lastMeasuredWidth? and isEqualForProperties(oldProps, @props, 'maxLineNumberDigits', 'fontSize', 'fontFamily')

  measureWidth: ->
    lineNumberNode = @refs.lineNumbers.getDOMNode().firstChild
    width = lineNumberNode.offsetWidth
    if width isnt @lastMeasuredWidth
      @props.onWidthChanged(@lastMeasuredWidth = width)

  lineNumberNodeForScreenRow: (screenRow) ->
    {renderedRowRange} = @props
    [startRow, endRow] = renderedRowRange

    unless startRow <= screenRow < endRow
      throw new Error("Requested screenRow #{screenRow} is not currently rendered")

    @refs.lineNumbers.getDOMNode().children[screenRow - startRow + 1]
