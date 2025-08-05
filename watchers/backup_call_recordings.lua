-- backup_call_recordings.lua

-- watch for any Notes window gaining focus
local wf = hs.window.filter.new{'Notes'}
wf:subscribe(hs.window.filter.windowFocused, function(win, appName)
  -- give it a 10 s buffer
  hs.timer.doAfter(10, function()
    local ok, err = hs.osascript.applescript([[
      -- 0) Prepare temporary directory for attachments
      set tmpDir to POSIX path of (path to temporary items) & "NotesMoveTmp/"
      do shell script "rm -rf " & quoted form of tmpDir & " && mkdir -p " & quoted form of tmpDir

      -- 1) Start notification
      display notification "MoveNotes script started" with title "MoveNotes Debug"

      -- 2) Identify source & destination and grab all notes
      tell application "Notes"
        set srcFolder to folder "Notes" of account "iCloud"
        set dstFolder to folder "Notes" of account "dongwook.recordings@gmail.com"
        set allNotes to notes of srcFolder
      end tell

      -- 3) Filter notes
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

      -- 4) If none, bail
      set matchCount to count of notesToMove
      display notification (matchCount as text) & " note(s) matched filter" with title "MoveNotes Debug"
      if matchCount = 0 then return

      -- 5) Move them
      repeat with n in notesToMove
        tell application "Notes"
          set noteTitle to name of n
          set attachList to attachments of n
        end tell
        display notification "Processing: " & noteTitle with title "MoveNotes Debug"

        set fileList to {}
        tell application "Notes"
          repeat with a in attachList
            set outPath to tmpDir & (name of a)
            save a in POSIX file outPath
            copy (POSIX file outPath as alias) to end of fileList
          end repeat
        end tell

        tell application "Notes"
          set newNote to make new note at dstFolder with properties {name:noteTitle, body:return}
          tell newNote
            repeat with fp in fileList
              make new attachment at end of attachments with data fp
            end repeat
          end tell
          delete n
        end tell

        display notification "Moved: " & noteTitle with title "MoveNotes Debug"
      end repeat

      -- 6) Done!
      display notification "MoveNotes completed: " & (matchCount as text) & " note(s) moved." with title "MoveNotes Debug"
    ]])
    if not ok then hs.alert.show("MoveNotes error: "..err) end
  end)
end)
