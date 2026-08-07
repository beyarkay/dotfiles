Set Shell "zsh"
Set FontFamily "Fira Code"
Set FontSize 30
Set LineHeight 1.03
Set Width 1320
Set Height 140
Set Padding 24
Set Theme "OneHalfDark"
Set TypingSpeed 0ms
Set CursorBlink false
Output "/tmp/prompt-screenshots.gif"

Hide
Type 'PROMPT="$(PROMPT_PREVIEW_ZSH_FORMAT=1 zsh ./scripts/prompt-preview.zsh clean)"; RPROMPT=""; PROMPT_EOL_MARK=""; clear'
Enter
Sleep 500ms
Show
Sleep 100ms
Screenshot "images/prompt-clean.png"
Sleep 300ms

Hide
Type 'PROMPT="$(PROMPT_PREVIEW_ZSH_FORMAT=1 zsh ./scripts/prompt-preview.zsh command)"; clear'
Enter
Sleep 500ms
Show
Sleep 100ms
Screenshot "images/prompt-command.png"
Sleep 300ms

Hide
Type 'PROMPT="$(PROMPT_PREVIEW_ZSH_FORMAT=1 zsh ./scripts/prompt-preview.zsh git)"; clear'
Enter
Sleep 500ms
Show
Sleep 100ms
Screenshot "images/prompt-git-state.png"
Sleep 300ms

Hide
Type 'PROMPT="$(PROMPT_PREVIEW_ZSH_FORMAT=1 zsh ./scripts/prompt-preview.zsh system)"; clear'
Enter
Sleep 500ms
Show
Sleep 100ms
Screenshot "images/prompt-system-alerts.png"
Sleep 300ms

Hide
Type 'PROMPT="$(PROMPT_PREVIEW_ZSH_FORMAT=1 zsh ./scripts/prompt-preview.zsh root)"; clear'
Enter
Sleep 500ms
Show
Sleep 100ms
Screenshot "images/prompt-root.png"
Sleep 300ms
