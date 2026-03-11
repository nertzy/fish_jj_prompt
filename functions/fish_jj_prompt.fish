function fish_jj_prompt
    # If jj isn't installed, there's nothing we can do
    # Return 1 so the calling prompt can deal with it
    if not command -sq jj
        return 1
    end

    # Walk up to find .jj/ repo root; check for disable file (no subprocess)
    set -l d $PWD
    while test -n "$d"
        if test -d "$d/.jj"
            test -f "$d/.disable-jj-prompt"; and return 1
            break
        end
        set d (string replace -r '/[^/]*$' '' -- $d)
    end

    # All jj queries use --color=never. Colors are applied in fish.
    #
    # Main query outputs structured plain text:
    #   @ line:       change_id \t commit_id \t status \t bookmarks_or_dot
    #   ancestor:     change_id \t bookmarks  (if bookmarked)
    #   ancestor:     .                       (if not bookmarked)
    #   behind:       B
    #
    # Ahead = total line count (excluding B lines).
    # Bookmark depth = |bookmark::@ ~ bookmark| via sub-query.
    set -l tmpl '
if(self.contained_in("::trunk() & ~::@"),
    "B\n",
    if(self.contained_in("@"),
        change_id.shortest() ++ "\t" ++
        commit_id.shortest() ++ "\t" ++
        separate(" ",
            if(conflict, "×"),
            if(divergent, "??"),
            if(hidden, "(hidden)"),
            if(immutable, "◆"),
            coalesce(
                if(empty, coalesce(
                    if(parents.len() > 1, "(merged)"),
                    "(empty)",
                )),
                "*",
            ),
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
                change_id.shortest() ++ "\t" ++ separate(",",
                    local_bookmarks.join(","),
                    if(tags, tags.join(",")),
                ) ++ "\n",
                if(tags,
                    change_id.shortest() ++ "\t" ++ tags.join(",") ++ "\n",
                    ".\n",
                )
            )
        )
    )
)
'
    set -l raw_lines (jj log --no-pager --no-graph --ignore-working-copy --color=never \
        -r '@ | trunk()..@ | (::trunk() & ~::@)' \
        -T $tmpl 2>/dev/null)
    or return 1

    # Colors
    set -l bold_brmagenta (set_color --bold brmagenta)
    set -l magenta (set_color magenta)
    set -l bold_brblue (set_color --bold brblue)
    set -l bold_brgreen (set_color --bold brgreen)
    set -l bold_brred (set_color --bold brred)
    set -l bold_yellow (set_color --bold yellow)
    set -l gray (set_color brblack)
    set -l reset (set_color normal)

    set -l info ""
    set -l has_conflict 0
    set -l behind 0
    set -l ahead 0
    set -l display_bookmarks

    for line in $raw_lines
        if test "$line" = B
            set behind (math $behind + 1)
            continue
        end

        set ahead (math $ahead + 1)
        set -l parts (string split \t -- $line)
        set -l nparts (count $parts)

        if test $nparts -ge 4
            # @ line: change_id, commit_id, status, bookmarks
            set -l status_color $bold_brgreen
            if string match -q '*×*' -- "$parts[3]"
                set status_color $bold_brred
                set has_conflict 1
            else if string match -q '*\?\?*' -- "$parts[3]"
                set status_color $bold_brred
            else if test "$parts[3]" = "*"
                set status_color $bold_yellow
            end
            set info "$bold_brmagenta$parts[1]$reset $bold_brblue$parts[2]$reset $status_color$parts[3]$reset"
            if test "$parts[4]" != "."
                for bookmark in (string split ',' -- $parts[4])
                    set bookmark (string trim -- $bookmark)
                    if test -n "$bookmark"
                        set -a display_bookmarks "$bold_brmagenta$bookmark$reset"
                    end
                end
            end
        else if test $nparts -eq 2
            # Ancestor with bookmarks: change_id, bookmarks
            set -l cid $parts[1]
            set -l depth_commits (jj log --no-pager --no-graph --ignore-working-copy --color=never \
                -r "$cid::@ ~ $cid" -T '".\n"' 2>/dev/null)
            set -l depth (count $depth_commits)
            for bookmark in (string split ',' -- $parts[2])
                set bookmark (string trim -- $bookmark)
                if test -n "$bookmark"
                    set -a display_bookmarks "$magenta$bookmark$magenta↑$depth$reset"
                end
            end
        end
        # "." lines (nparts=1, not "B") just count toward ahead
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
        set -l at_color (set_color --bold green)
        if test $has_conflict -eq 1
            set at_color (set_color --bold red)
        end
        printf ' (%s%s%s)' "$at_color" @ "$reset $info"
    end
end
