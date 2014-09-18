fs = require 'fs-plus'
path = require 'path'
AddDialog = require atom.packages.resolvePackagePath('tree-view') \
  + '/lib/add-dialog'

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


  create: ->
    # TODO: Refactor this, it smells a bit. Look into DI containers for node?
    # At least fix the smelliness around the validator instantiation
    # and multiple lexicon assignments
    sketcher = new Sketcher(@lexiconShim, \
      new SketchNameValidator(@lexiconShim))

    sketcher.go()
    # TODO: Add events/messages

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
      console.log("successful onConfirm", relativePath)
      super(relativePath)

  getValidationErrors: (relativePath) ->
    sketchName = path.basename(relativePath)
    return @validator.validateAll(sketchName)

class Sketcher
  constructor: (@lexicon, @validator) ->

  go: () ->
    # TODO: Maybe "cache" this query result somewhere
    treeView = atom.workspaceView.find(".tree-view").view()

    # TODO:Next block is copied from tree-view.add
    # Theoretically if they were to change their behavior
    # this would be out of sync and might break. Probably not a big deal?
    selectedEntry = treeView.selectedEntry() or @root
    selectedPath = selectedEntry.getPath()

    addDialog = new AddNewSketchDialog(selectedPath, @lexicon, @validator)
    addDialog.on 'directory-created', (event, createdPath) =>
      #console.log event, createdPath, addDialog
      @onDirectoryCreated createdPath
      false

    addDialog.attach()

  onDirectoryCreated: (directoryPath) ->
    fileMaker = new SketchFileMaker()
    fileMaker.makeIn directoryPath
    console.log 'directory-created', arguments

  class SketchFileMaker
    constructor: () ->
      #nothing yet

    extractPdeFileNameFromDirectoryPath: (directoryPath) ->
      result = path.basename directoryPath
      return result

    makeIn: (directoryPath) ->
      fileName = @extractPdeFileNameFromDirectoryPath directoryPath
      fileName = fileName + '.pde'
      fullFilePath = path.join(directoryPath, fileName)
      # TODO: any template when writing the file?
      # TODO: Need to open the file in the editor to expand the snippet
      @writeNewSketchFile(fullFilePath, "")

    writeNewSketchFile: (fullFilePath, content) ->
      fs.writeFileSync(fullFilePath, content)
      console.log 'file-created', [fullFilePath]
