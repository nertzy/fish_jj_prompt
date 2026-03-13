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
        change_id.shortest() ++
            if(divergent, "/" ++ change_offset) ++
        "\t" ++
        if(self.contained_in("mine()"), ".", coalesce(author.email().local(), author.name(), ".")) ++
        "\t" ++
        coalesce(
            separate(",",
                if(local_bookmarks, local_bookmarks.join(",")),
                if(tags, tags.join(",")),
            ),
            ".",
        ) ++ "\t" ++
        working_copies ++ "\t" ++
        commit_id.shortest() ++ "\t" ++
        separate(" ",
            if(conflict, "×"),
            if(divergent, "(divergent)"),
            if(hidden, "(hidden)"),
            coalesce(
                if(empty, coalesce(
                    if(parents.len() > 1, "(merged)"),
                    "(empty)",
                )),
                "*",
            ),
        ) ++ "\t" ++
        immutable ++ "\t" ++
        if(description, description.first_line(), "(no description set)") ++ "\n"
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
    set -l has_immutable 0
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

        if test $nparts -ge 8
            # @ line fields: change_id[1] author[2] bookmarks[3] working_copies[4] commit_id[5] status[6] immutable[7] description[8]
            # Separate (divergent) from other status flags for distinct coloring
            set -l st $parts[6]
            set -l divergent_label ""
            set -l cid_color $bold_brmagenta
            if string match -q '*(divergent)*' -- "$st"
                set -l divergent_esc (printf '\e[1;38;5;9m')
                set divergent_label " $divergent_esc(divergent)$reset"
                set cid_color $divergent_esc
                set st (string replace ' (divergent)' '' -- $st)
                set st (string replace '(divergent) ' '' -- $st)
                set st (string replace '(divergent)' '' -- $st)
            end
            set -l status_color $bold_brgreen
            if string match -q '*×*' -- "$st"
                set status_color $bold_brred
                set has_conflict 1
            else if test "$st" = "*"
                set status_color $bold_yellow
            end
            if test "$parts[7]" = true
                set has_immutable 1
            end
            # Author (only shown if not mine)
            set -l author_label ""
            if test "$parts[2]" != "."
                set -l author_color (printf '\e[1;38;5;3m')
                set author_label " $author_color$parts[2]$reset"
            end
            # Bookmarks at @
            set -l at_bookmarks ""
            if test "$parts[3]" != "."
                set -l at_bm_list
                for bookmark in (string split ',' -- $parts[3])
                    set bookmark (string trim -- $bookmark)
                    if test -n "$bookmark"
                        set -a at_bm_list "$bold_brmagenta$bookmark$reset"
                    end
                end
                if test (count $at_bm_list) -gt 0
                    set at_bookmarks " "(string join ' ' $at_bm_list)
                end
            end
            # Show workspace if multiple workspaces exist
            set -l workspace_label ""
            set -l wc_count (jj workspace list --no-pager --color=never 2>/dev/null | count)
            if test $wc_count -gt 1; and test -n "$parts[4]"
                set -l bold_brgreen_color (set_color --bold brgreen)
                set workspace_label " $bold_brgreen_color$parts[4]$reset"
            end
            # Description truncated to 24 chars
            set -l desc_label ""
            if test -n "$parts[8]"
                set -l desc (string sub -l 24 -- $parts[8])
                if test (string length -- $parts[8]) -gt 24
                    set desc "$desc…"
                end
                if test "$parts[8]" = "(no description set)"
                    set desc_label " $status_color$desc$reset"
                else
                    set desc_label " "(printf '\e[1m')"$desc$reset"
                end
            end
            set info "$cid_color$parts[1]$reset$author_label$at_bookmarks$workspace_label $bold_brblue$parts[5]$reset $status_color$st$reset$divergent_label$desc_label"
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
        else if test $has_immutable -eq 1
            set at_color (printf '\e[1;38;5;14m')
        end
        printf ' (%s%s%s)' "$at_color" @ "$reset $info"
    end
end
