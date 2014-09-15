fs = require 'fs-plus'
path = require 'path'

module.exports =
  activate: ->
    atom.workspaceView.command "new-processing-sketch:create", => @create()

  create: ->
    # Ask for the Sketch name
    # todo: Probably need some more validation on names
    # Create the folder in the selected path
    # Create a single .pde file with the same name inside that folder
    treeView = atom.workspaceView.find(".tree-view").view()

    #treeView.trigger "tree-view:add-file"
    treeView.add false
    addDialog = atom.workspaceView.find(".tree-view-dialog").view()
    #addDialog.promptText.text("yo momma")
    addDialog.on 'directory-created', (event, createdPath) =>
      #console.log event, createdPath, addDialog
      @onDirectoryCreated event, createdPath, addDialog
      false

  onDirectoryCreated: (e, c, a) ->
    @createMatchingFile(c)
    console.log 'directory-created', arguments
    #@trigger 'directory-created', [e, c, a]

  createMatchingFile: (directoryPath) ->
    fileName = @extractPdeFileName directoryPath
    fileName = fileName + '.pde'
    #todo: ^ refactor out that .pde string
    fullFilePath = path.join(directoryPath, fileName)
    #todo: any template when writing the file?
    fs.writeFileSync(fullFilePath, "")
    console.log 'file-created', [fullFilePath]
    #@trigger 'file-created', [directoryPath, filePath]

  onFileCreated: (filePath) ->
    console.log 'after file created', [filePath]
    #todo: Open the file?
    #todo: Expand in treeview?

  extractPdeFileName: (directoryInfo) ->
    result = path.basename directoryInfo
    return result
