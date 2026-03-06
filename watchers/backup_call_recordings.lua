-- backup_call_recordings.lua

-- watch for any Notes window gaining focus
local wf = hs.window.filter.new{'Notes'}
wf:subscribe(hs.window.filter.windowFocused, function(win, appName)
  -- give it a 10 s buffer
  hs.timer.doAfter(10, function()
    local home = os.getenv("HOME")
    local attachDir = home .. "/Library/Containers/com.apple.Notes/Data/Library/CoreData/Attachments/"
    local groupDir = home .. "/Library/Group Containers/group.com.apple.notes/"
    local tmpDir = "/tmp/NotesMoveTmp"

    local ok, result = hs.osascript.applescript(string.format([[
      set stepName to "init"
      try
        set tmpDir to "%s/"
        set attachDir1 to "%s"
        set attachDir2 to "%s"
        do shell script "rm -rf " & quoted form of tmpDir & " && mkdir -p " & quoted form of tmpDir

        set stepName to "get folders"
        tell application "Notes"
          set srcFolder to folder "Notes" of account "iCloud"
          set dstFolder to folder "Notes" of account "dongwook.recordings@gmail.com"
          set allNotes to notes of srcFolder
        end tell

        set stepName to "filter notes"
        set notesToMove to {}
        repeat with n in allNotes
          tell application "Notes"
            set noteName to name of n
            set attachCount to count of attachments of n
          end tell
          if ((noteName contains "Call with ") or (noteName contains "Call Recording")) and attachCount = 1 then
            copy n to end of notesToMove
          end if
        end repeat

        set matchCount to count of notesToMove
        if matchCount = 0 then return "no notes matched"

        repeat with n in notesToMove
          set stepName to "get note info"
          tell application "Notes"
            set noteTitle to name of n
            set noteBody to body of n
            set attachName to name of attachment 1 of n
          end tell

          set stepName to "find attachment: " & attachName
          -- Normalize to NFD for APFS matching and add wildcard for file extension
          set nfdName to do shell script "python3 -c \"import unicodedata,sys; print(unicodedata.normalize('NFD', sys.argv[1]))\" " & quoted form of attachName
          set attachPath to do shell script "find " & quoted form of attachDir1 & " -name " & quoted form of (nfdName & "*") & " -type f 2>/dev/null | head -1 || true"
          if attachPath = "" then
            set attachPath to do shell script "find " & quoted form of attachDir2 & " -name " & quoted form of (nfdName & "*") & " -type f 2>/dev/null | head -1 || true"
          end if
          if attachPath = "" then
            return "FAIL at [" & stepName & "]: file not found on disk"
          end if

          set stepName to "copy attachment: " & attachName
          set tmpFile to tmpDir & attachName
          do shell script "cp " & quoted form of attachPath & " " & quoted form of tmpFile

          set stepName to "create note: " & noteTitle
          tell application "Notes"
            set newNote to make new note at dstFolder with properties {name:noteTitle, body:noteBody}
            make new attachment at end of attachments of newNote with data (POSIX file tmpFile)
            delete n
          end tell
        end repeat

        do shell script "rm -rf " & quoted form of tmpDir
        return "moved " & (matchCount as text) & " note(s)"
      on error errMsg number errNum
        return "FAIL at [" & stepName & "]: " & errMsg & " (" & (errNum as text) & ")"
      end try
    ]], tmpDir, attachDir, groupDir))

    local msg = ok and tostring(result) or "AppleScript failed"
    print("[MoveNotes] " .. msg)
    if msg ~= "no notes matched" then
      hs.alert.show("MoveNotes: " .. msg)
    end
  end)
end)
