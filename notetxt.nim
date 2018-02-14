import re, system, unittest, typetraits, ospaths, os, tables, times

type
  Note* = object
    title*: string
    path*: string
    tags*: seq[string]
    lastWriteTime*: Time
    lastAccessTime*: Time
    creationTime*: Time

  Notes* = object
    dir*: string
    notes*: seq[Note]

proc isNil(note: Note): bool =
  return note.title.isNil or note.path.isNil

let titleRegex = re"^([A-Za-z0-9 -_:]+)\n(?:-|=)+\n"

proc getNoteTitle(str: string): string =
  var matches: array[1, string]
  if str.match(titleRegex, matches):
    return matches[0]
  return nil

proc getNoteTag(path: string, dir: string): string =
  let real_path = expandFilename(path)
  let expanded_dir = expandFilename(dir)
  let (real_path_dir, _, _) = splitFile(real_path)
  return real_path_dir.replace(re(expanded_dir), "")

proc getNoteFromPath(path: string, dir: string): Note =
  let file = open(path, fmRead)
  let fileContents = file.readAll()
  file.close()

  # only take the first 512 characters into account
  let first512chars = fileContents[..512]
  let title = first512chars.getNoteTitle()

  let tag = getNoteTag(path, dir)
  let info = getFileInfo(path)

  if not title.isNil:
    return Note(title: title,
                path: path,
                tags: @[tag],
                lastWriteTime: info.lastWriteTime,
                lastAccessTime: info.lastAccessTime,
                creationTime: info.creationTime)

proc getNotesFromDir(dir: string): Notes =
  var notes = Notes(dir: dir, notes: @[])
  var path_to_note = initTable[string, Note]()

  for path in walkDirRec(dir):
    let expanded_path = expandFilename(path)
    var note = getNoteFromPath(path, dir)
    if not note.isNil:
      notes.notes.add(note)
      path_to_note[expanded_path] = note

  for link in walkDirRec(dir, {pcDir, pcLinkToFile}):
    let (link_dir, _, _) = splitFile(link)
    let real_path = link_dir / expandSymlink(link)
    let expanded_link_path = expandFilename(link)

    let tag = getNoteTag(expanded_link_path, dir)
    if path_to_note.hasKey(real_path):
      path_to_note[real_path].tags.add(tag)

  return notes

suite "notetxt test suite":
  test "simple getNoteTitle tests":
    check(getNoteTitle("Test note\n---------\n") == "Test note")
    check(getNoteTitle("Some other note") == nil)

  test "simple getNoteFromPath test":
    let path = "tests/notes/test-note.md"
    let note = getNoteFromPath(path, "tests/")
    check(note.title == "Test note")
    check(note.path == path)
    check(note.tags.len == 1)
    check(note.tags[0] == "/notes")
    let info = getFileInfo(path)

    check(note.lastWriteTime == info.lastWriteTime)
    check(note.lastAccessTime == info.lastAccessTime)
    check(note.creationTime == info.creationTime)

  test "fialed getNoteFromPath test (too long title)":
    let path = "tests/notes/test-note-very-long.md"
    let note = getNoteFromPath(path, ".")
    check(note.isNil)

  test "fialed getNoteFromPath test (pdf)":
    let path = "tests/notes/otherfile.pdf"
    let note = getNoteFromPath(path, ".")
    check(note.isNil)

  test "get Notes from directory":
    let dir = "tests/"
    let notes = getNotesFromDir(dir)
    check(notes.dir == dir)
    check(notes.notes.len == 1)
