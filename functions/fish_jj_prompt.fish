function fish_jj_prompt
    # If jj isn't installed, there's nothing we can do
    # Return 1 so the calling prompt can deal with it
    if not command -sq jj
        return 1
    end

    set -l jj_root (jj root --quiet 2>/dev/null)
    if test -n "$jj_root"; and test -f "$jj_root/.disable-jj-prompt"
        return 1
    end

    # Single jj call: query all ancestors of @ and commits behind trunk.
    # For @: outputs colored working copy info, TAB, then bookmark data.
    # For other ancestors: outputs bookmark data (names or ".").
    # For behind-trunk commits: outputs "B".
    set -l raw_lines (jj log --no-pager --no-graph --ignore-working-copy --color=always \
        -r '(trunk()..@ | trunk()) | (::trunk() & ~::@)' \
        --template '
            if(self.contained_in("::trunk() & ~::@"),
                "B\n",
                if(self.contained_in("@"),
                    label("working_copy",
                        separate(" ",
                            change_id.shortest(),
                            local_bookmarks.join(", "),
                            commit_id.shortest(),
                            if(conflict, label("conflict", "×")),
                            if(divergent, label("divergent", "??")),
                            if(hidden, label("hidden prefix", "(hidden)")),
                            if(immutable, label("node immutable", "◆")),
                            coalesce(
                                if(empty, coalesce(
                                    if(parents.len() > 1, label("empty", "(merged)")),
                                    label("empty", "(empty)"),
                                )),
                                label("description placeholder", "*")
                            ),
                        )
                    ) ++ "\t"
                ) ++
                coalesce(
                    if(!self.contained_in("trunk()") && !self.contained_in("@"),
                        separate(",",
                            if(local_bookmarks, local_bookmarks.join(",")),
                            if(tags, tags.join(",")),
                        ),
                    ),
                    ".",
                ) ++ "\n"
            )
        ' 2>/dev/null)
    or return 1

    # Parse output: TAB line = @ (info + bookmarks), "B" = behind, rest = ancestor bookmarks
    set -l info ""
    set -l ancestor_bookmarks
    set -l behind 0

    for line in $raw_lines
        if string match -rq "\t" -- $line
            set -l parts (string split \t -- $line)
            set info $parts[1]
            set -a ancestor_bookmarks $parts[2]
        else if test "$line" = B
            set behind (math $behind + 1)
        else
            set -a ancestor_bookmarks $line
        end
    end

    # Build bookmark display with depth from @
    set -l magenta (set_color magenta)
    set -l gray (set_color brblack)
    set -l reset (set_color normal)

    set -l display_bookmarks
    set -l depth 0
    for entry in $ancestor_bookmarks
        if test "$entry" != "."
            for bookmark in (string split ',' -- $entry)
                set bookmark (string trim -- $bookmark)
                if test -n "$bookmark"
                    if test $depth -eq 0
                        set -a display_bookmarks "$magenta$bookmark$reset"
                    else
                        set -a display_bookmarks "$magenta$bookmark$magenta↑$depth$reset"
                    end
                end
            end
        end
        set depth (math $depth + 1)
    end

    # Assemble prompt
    if test -n "$info"
        set -l ahead (math (count $ancestor_bookmarks) - 1)
        if test (count $display_bookmarks) -gt 0
            set info "$info "(string join ' ' $display_bookmarks)
        end
        if test $ahead -gt 0
            set info "$info $gray↑$ahead$reset"
        end
        if test $behind -gt 0
            set info "$info $gray↓$behind$reset"
        end
        set -l green (set_color --bold green)
        printf ' (%s%s%s)' "$green" @ "$reset $info"
    end
end
