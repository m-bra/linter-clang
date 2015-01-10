{Range, Point, BufferedProcess, BufferedNodeProcess} = require 'atom'
linterPath = atom.packages.getLoadedPackage("linter").path
Linter = require "#{linterPath}/lib/linter"
path = require 'path'
fs = require 'fs'
# ClangFlags = require 'clang-flags'

class LinterClang extends Linter
  # The syntax that the linter handles. May be a string or
  # list/tuple of strings. Names should be all lowercase.
  @syntax: ['source.c++', 'source.c']

  # A string, list, tuple or callable that returns a string, list or tuple,
  # containing the command line (with arguments) used to lint.
  cmd: '-fsyntax-only -fno-caret-diagnostics'
  isCpp: false

  executablePath: null

  linterName: 'clang'

  errorStream: 'stderr'

  fileName: ''

  lintFile: (filePath, callback) ->
    oldCmd = @cmd

    if @isCpp
      @cmd += ' ' + atom.config.get 'linter-clang.clangDefaultCppFlags'
    else
      @cmd += ' ' + atom.config.get 'linter-clang.clangDefaultCFlags'

    includepaths = atom.config.get 'linter-clang.clangIncludePaths'

    # read other include paths from file in project
    filename = path.resolve(atom.project.getPaths()[0], '.linter-clang-includes')
    if fs.existsSync filename
        file = fs.readFileSync filename, 'utf8'
        file = file.replace(/(\r\n|\n|\r)/gm, ' ')
        includepaths = "#{includepaths} #{file}"

    split = includepaths.split " "

    # concat includepath
    for custompath in split
      if custompath.length > 0
        # if the path is relative, resolve it
        custompathResolved = path.resolve(atom.project.getPaths()[0], custompath)
        @cmd = "#{@cmd} -I #{custompathResolved}"
    if atom.config.get 'linter-clang.clangSuppressWarnings'
      @cmd = "#{@cmd} -w"
    # build the command with arguments to lint the file
    {command, args} = @getCmdAndArgs(filePath)

    # add file to regex to filter output to this file,
    # need to change filename a bit to fit into regex
    @regex = filePath.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&") +
        ':(?<line>\\d+):.+: .*((?<error>error)|(?<warning>warning)): (?<message>.*)'

    if atom.inDevMode()
      console.log 'is node executable: ' + @isNodeExecutable

    # use BufferedNodeProcess if the linter is node executable
    if @isNodeExecutable
      Process = BufferedNodeProcess
    else
      Process = BufferedProcess

    # options for BufferedProcess, same syntax with child_process.spawn
    options = {cwd: @cwd}

    stdout = (output) =>
      if atom.inDevMode()
        console.log 'stdout', output
      if @errorStream == 'stdout'
        @processMessage(output, callback)

    stderr = (output) =>
      if atom.inDevMode()
        console.warn 'stderr', output
      if @errorStream == 'stderr'
        @processMessage(output, callback)

    new Process({command, args, options, stdout, stderr})
    # restore cmd
    @cmd = oldCmd;

  constructor: (editor) ->
    super(editor)
    if editor.getGrammar().name == 'C++'
      @cmd = 'clang++ ' + @cmd + ' -x c++ -std=c++11 -fcxx-exceptions'
      @grammar = '+'
      @isCpp = true
    if editor.getGrammar().name == 'C'
      @cmd = 'clang ' + @cmd + ' -x c -std=c11 -fexceptions'
      @grammar = 'c'

    # @cmd += ' ' + ClangFlags.getClangFlags(editor.getPath()).join ' '

    atom.config.observe 'linter-clang.clangExecutablePath', =>
      @executablePath = atom.config.get 'linter-clang.clangExecutablePath'

  destroy: ->
    atom.config.unobserve 'linter-clang.clangExecutablePath'

  createMessage: (match) ->
    # message might be empty, we have to supply a value
    if match and match.type == 'parse' and not match.message
      message = 'error'

    super(match)

module.exports = LinterClang
