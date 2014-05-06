React = require 'react'
{div, span} = require 'reactionary'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'
EditorView = require './editor-view'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  render: ->
    div className: 'lines'

  componentWillMount: ->
    @measuredLines = new WeakSet

  componentDidMount: ->
    @measureLineHeightAndCharWidth()

  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props,  'renderedRowRange', 'fontSize', 'fontFamily', 'lineHeight', 'showIndentGuide')

    {renderedRowRange, pendingChanges} = newProps
    for change in pendingChanges
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (prevProps) ->
    if not prevProps.renderedRowRange? or prevProps.lineHeight isnt @props.lineHeight
      @renderLines()
    else
      @updateRenderedLines(prevProps.renderedRowRange)

    @measureLineHeightAndCharWidth() unless isEqualForProperties(prevProps, @props, 'fontSize', 'fontFamily', 'lineHeight')
    # @clearScopedCharWidths() unless isEqualForProperties(prevProps, @props, 'fontSize', 'fontFamily')
    # @measureCharactersInNewLines() unless @props.scrollingVertically

  measureLineHeightAndCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeight = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor} = @props
    editor.setLineHeight(lineHeight)
    editor.setDefaultCharWidth(charWidth)

  renderLines: ->
    [startRow, endRow] = @props.renderedRowRange
    @getDOMNode().innerHTML = @buildHTMLForScreenRowRange(startRow, endRow)

  updateRenderedLines: (oldRenderedRowRange) ->
    [oldStartRow, oldEndRow] = oldRenderedRowRange
    [newStartRow, newEndRow] = @props.renderedRowRange
    node = @getDOMNode()

    if newEndRow <= oldStartRow or newStartRow >= oldEndRow
      @renderLines()
      return

    if newEndRow > oldEndRow
      for lineNode in @buildLineNodesForScreenRowRange(oldEndRow, newEndRow)
        node.appendChild(lineNode)
    else if newEndRow < oldEndRow
      extraLineCount = oldEndRow - newEndRow
      while extraLineCount > 0
        node.removeChild(node.lastChild)
        extraLineCount--

    if newStartRow < oldStartRow
      oldFirstLineNode = node.firstChild
      for lineNode in @buildLineNodesForScreenRowRange(newStartRow, Math.min(newEndRow, oldStartRow))
        node.insertBefore(lineNode, oldFirstLineNode)
    else if newStartRow > oldStartRow
      extraLineCount = newStartRow - oldStartRow
      while extraLineCount > 0
        node.removeChild(node.firstChild)
        extraLineCount--

  buildLineNodesForScreenRowRange: (startRow, endRow) ->
    wrapper = document.createElement('div')
    wrapper.innerHTML = @buildHTMLForScreenRowRange(startRow, endRow)
    toArray(wrapper.children)

  buildHTMLForScreenRowRange: (startRow, endRow) ->
    {editor} = @props

    linesHTML = ""
    for tokenizedLine, i in editor.linesForScreenRows(startRow, endRow - 1)
      linesHTML += @buildHTMLForTokenizedLine(tokenizedLine, startRow + i)
    linesHTML

  buildHTMLForTokenizedLine: (screenLine, screenRow) ->
    {tokens, text, lineEnding, fold, isSoftWrapped} =  screenLine
    {editor, lineHeight, showIndentGuide, mini} = @props

    attributes =
      class: "line"
      style: "-webkit-transform: translate3d(0, #{screenRow * lineHeight}px, 0)"

    if fold
      attributes.class += " fold"
      attributes['fold-id'] = fold.id

    # invisibles = @invisibles if @showInvisibles
    # eolInvisibles = @getEndOfLineInvisibles(screenLine)
    # htmlEolInvisibles = @buildHtmlEndOfLineInvisibles(screenLine)

    invisibles = {}
    eolInvisibles = {}
    htmlEolInvisibles = ""

    indentation = EditorView.buildIndentation(screenRow, editor)

    EditorView.buildLineHtml({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, showIndentGuide, indentation, editor, mini})

  measureCharactersInNewLines: ->
    [visibleStartRow, visibleEndRow] = @props.renderedRowRange
    node = @getDOMNode()

    for tokenizedLine, i in @props.editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
      unless @measuredLines.has(tokenizedLine)
        lineNode = node.children[i]
        @measureCharactersInLine(tokenizedLine, lineNode)

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes}, tokenIndex in tokenizedLine.tokens
      charWidths = editor.getScopedCharWidths(scopes)

      for char in value
        unless charWidths[char]?
          unless textNode?
            rangeForMeasurement ?= document.createRange()
            iterator =  document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
            textNode = iterator.nextNode()
            textNodeIndex = 0
            nextTextNodeIndex = textNode.textContent.length

          while nextTextNodeIndex <= charIndex
            textNode = iterator.nextNode()
            textNodeIndex = nextTextNodeIndex
            nextTextNodeIndex = textNodeIndex + textNode.textContent.length

          i = charIndex - textNodeIndex
          rangeForMeasurement.setStart(textNode, i)
          rangeForMeasurement.setEnd(textNode, i + 1)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          editor.setScopedCharWidth(scopes, char, charWidth)

        charIndex++

    @measuredLines.add(tokenizedLine)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()
