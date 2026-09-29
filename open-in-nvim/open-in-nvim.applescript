on open theFiles
	tell application "iTerm2"
		activate
		repeat with i from 1 to count of theFiles
			set p to POSIX path of (item i of theFiles)
			if (count of windows) is 0 then
				create window with default profile
				set newSession to current session of current window
			else
				tell current window
					set newTab to create tab with default profile
				end tell
				set newSession to current session of newTab
			end if
			tell newSession to write text "builtin cd " & quoted form of (do shell script "dirname " & quoted form of p) & " && exec nvim " & quoted form of p
		end repeat
	end tell
end open

on run
	open (choose file)
end run
