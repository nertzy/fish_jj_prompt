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

    # Build depth expression dynamically: coalesce(if(@-,"1"),if(@--,"2"),...,"?")
    if not set -q __fish_jj_depth_expr
        set -l parts
        set -l dashes ''
        for i in (seq 1 20)
            set dashes "$dashes-"
            set -a parts 'if(self.contained_in("@'$dashes'"),"'$i'")'
        end
        set -g __fish_jj_depth_expr 'coalesce('(string join ',' $parts)',"?")'
    end

    # jj template stored in a variable to avoid fish parser escaping issues.
    # Single jj call: query all ancestors of @ and commits behind trunk.
    # For @: outputs colored working copy info, TAB, then bookmark data.
    # For other ancestors with bookmarks: outputs "depth:bookmark_data".
    # For other ancestors without bookmarks: outputs ".".
    # For behind-trunk commits: outputs "B".
    set -l depth_expr $__fish_jj_depth_expr
    set -l tmpl '
if(self.contained_in("::trunk() & ~::@"),
    "B\n",
    if(self.contained_in("@"),
        label("working_copy",
            separate(" ",
                change_id.shortest(),
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
        ) ++ "\t" ++
        if(self.contained_in("trunk()"),
            ".",
            coalesce(
                separate(",",
                    if(local_bookmarks, local_bookmarks.join(",")),
                    if(tags, tags.join(",")),
                ),
                ".",
            ),
        ) ++ "\n"
    ,
        if(self.contained_in("trunk()"),
            ".\n",
            if(local_bookmarks,
                '$depth_expr' ++ ":" ++ separate(",",
                    local_bookmarks.join(","),
                    if(tags, tags.join(",")),
                ) ++ "\n",
                if(tags,
                    '$depth_expr' ++ ":" ++ tags.join(",") ++ "\n",
                    ".\n",
                )
            )
        )
    )
)
'
    set -l raw_lines (jj log --no-pager --no-graph --ignore-working-copy --color=always \
        -r '@ | trunk()..@ | (::trunk() & ~::@)' \
        -T $tmpl 2>/dev/null)
    or return 1

    # Parse output
    set -l info ""
    set -l behind 0
    set -l ahead 0

    set -l bold_magenta (set_color --bold magenta)
    set -l magenta (set_color magenta)
    set -l gray (set_color brblack)
    set -l reset (set_color normal)

    set -l display_bookmarks

    for line in $raw_lines
        if string match -rq "\t" -- $line
            # TAB line: @ info + bookmark data
            set -l parts (string split \t -- $line)
            set info $parts[1]
            # @ bookmarks at depth 0 (bold, matching jj log style)
            if test "$parts[2]" != "."
                for bookmark in (string split ',' -- $parts[2])
                    set bookmark (string trim -- $bookmark)
                    if test -n "$bookmark"
                        set -a display_bookmarks "$bold_magenta$bookmark$reset"
                    end
                end
            end
        else if test "$line" = B
            set behind (math $behind + 1)
        else
            set ahead (math $ahead + 1)
            if test "$line" != "."
                # Parse "depth:bookmark1,bookmark2" format
                set -l parts (string split -m1 ':' -- $line)
                set -l depth $parts[1]
                set -l bm_data $parts[2]
                for bookmark in (string split ',' -- $bm_data)
                    set bookmark (string trim -- $bookmark)
                    if test -n "$bookmark"
                        set -a display_bookmarks "$magenta$bookmark$magenta↑$depth$reset"
                    end
                end
            end
        end
    end

    # Assemble prompt
    if test -n "$info"
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
