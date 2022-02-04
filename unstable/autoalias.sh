# 
# AutoAlias
# 
# look through your `history`, and automatically suggest aliases for commands
# you use most frequently
# 
# Maybe something like this?:
# ```
#     ╰→ curl cheat.sh/history
#      cheat:history
#     # To see most used top 10 commands:
#     history | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl | head -n10
# ```

