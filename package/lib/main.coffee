fs = require 'fs-plus'
path = require 'path'
AddDialog = require atom.packages.resolvePackagePath('tree-view') \
  + '/lib/add-dialog'
{Emitter} = require 'event-kit'

emitter = new Emitter()

module.exports =
  activate: ->
    # TODO: Refactor out the classes and modules so they're not loaded
    # too early.
    atom.workspaceView.command "new-processing-sketch:create", => @create()
    # Hacky version of "localization" for less refactoring later
    @lexiconShim =
      "SketchStartsWithNumeric": "The sketch name cannot start with a number."
      "SketchContainsIllegalCharacters": "The sketch name must contain only digits, letters, and underscores."
      "SketchMustBeLongerThan": "The sketch name must be at least three characters long."
      "ErrorDelimiter": " "
    atom.config.setDefaults "new-processing-sketch",
      "default-snippet": "newprocessingsketch"

  create: ->
    # TODO: Refactor this, it smells a bit. Look into DI containers for node?
    # At least fix the smelliness around the validator instantiation
    # and multiple lexicon assignments
    sketcher = new Sketcher(@lexiconShim, \
      new SketchNameValidator(@lexiconShim))

    sketcher.go()
    # TODO: Add events/messages

  deactivate: ->
    emitter.dispose()

class SketchNameValidator
  constructor: (@lexicon) ->
    @minimumLength = 3

  validateAll:(sketchName)->
    errors = []
    @doesntStartWithNumeric errors, sketchName
    @doesntContainIllegalCharacters errors, sketchName
    @containsMinimumCharacters errors, sketchName
    return errors

  doesntStartWithNumeric:(addTo, sketchName)->
    if /^[0-9]/.test(sketchName)
      addTo.push @lexicon["SketchStartsWithNumeric"]

  doesntContainIllegalCharacters:(addTo, sketchName) ->
    # no periods, only letters and numbers, and underscores
    # TODO: Java allows diacritics in its class names so
    # theoretically this check would be too greedy. I am
    # not sure how Processing deals with it or if this is
    # even a practical concern to have. Figure out those.
    # Maybe it can be configurable?

    if !/^[a-zA-Z0-9_]*$/.test(sketchName)
      addTo.push @lexicon["SketchContainsIllegalCharacters"]

  containsMinimumCharacters:(addTo, sketchName) ->
    if sketchName.length < @minimumLength
      minLength = @minimumLength
      # TODO: figure out how to get this string interpolation to work
      message = @lexicon["SketchMustBeLongerThan"]
      addTo.push message


class AddNewSketchDialog extends AddDialog
  constructor: (initialPath, @lexicon, @validator) ->
    super(initialPath, false) #Never creating a file in this dialog

  onConfirm: (relativePath) ->
    errors = @getValidationErrors relativePath

    if errors.length > 0
      console.log("errors:", errors)
      message = errors.join @lexicon["ErrorDelimiter"]
      @showError message
    else
      # Also run Atom's base validation, and actually create
      # the sketch files using the built-in Atom functionality
      super(relativePath)

  getValidationErrors: (relativePath) ->
    sketchName = path.basename(relativePath)
    return @validator.validateAll(sketchName)

class Sketcher
  constructor: (@lexicon, @validator) ->

  queryTreeView: ()->
    return atom.workspaceView.find(".tree-view").view()

  go: () ->
    treeView = @queryTreeView()

    selectedEntry = treeView.selectedEntry() or treeView.root
    selectedPath = selectedEntry.getPath()

    emitter.on "new-processing-sketch:sketch-created", \
    (fullFilePath, content) =>
      console.log "nps:sc", arguments
      @onFileCreated(fullFilePath, content)


    addDialog = new AddNewSketchDialog(selectedPath, @lexicon, @validator)
    addDialog.on 'directory-created', (event, directoryPath) =>
      @onDirectoryCreated(event, directoryPath)
    addDialog.attach()

  onFileCreated: (parameters)->
    filePath = parameters.filePath
    console.log "onFileCreated: ", parameters
    @selectFileInTreeView(filePath)
    @expandSnippetInFile(filePath)

  expandSnippetInFile: (filePath) ->
    editor = atom.workspaceView.getActiveView()
    expander = new DefaultSnippetExpander(editor)
    expander.expand()

  selectFileInTreeView:(filePath) ->
    treeView = @queryTreeView()
    #treeView.selectEntryForPath(filePath)
    #treeView.openSelectedEntry(true)# "tree-view:open-selected-entry"
    atom.workspaceView.open(filePath)
    atom.workspaceView.trigger 'tree-view:reveal-active-file'

  onDirectoryCreated: (event, directoryPath) ->
    fileMaker = new SketchFileMaker()
    fileMaker.makeIn directoryPath

class SketchFileMaker
  constructor: () ->

  extractPdeFileNameFromDirectoryPath: (directoryPath) ->
    result = path.basename directoryPath
    return result

  makeIn: (directoryPath) ->
    fileName = @extractPdeFileNameFromDirectoryPath directoryPath
    fileName = fileName + '.pde'
    fullFilePath = path.join(directoryPath, fileName)
    @writeNewSketchFile(fullFilePath, "")

  writeNewSketchFile: (fullFilePath, content) ->
    fs.writeFileSync(fullFilePath, content)
    emitter.emit("new-processing-sketch:sketch-created",\
    "filePath":fullFilePath
    "content":content)

class DefaultSnippetExpander
  constructor: (@editorView) ->

  expand: ->
    snippet = @getDefaultSnippet()
    # A completely empty string ("") as a setting will cause Atom to use the
    # default value. So if someone wants to overwrite the default snippet with
    # an empty snippet they should use a space " ".
    if(snippet && snippet.trim().length > 0)
      @editorView.setText(snippet)
      @editorView.trigger("snippets:expand")

  getDefaultSnippet: ->
    return atom.config.get("new-processing-sketch.default-snippet")
