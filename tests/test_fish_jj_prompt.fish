# Test suite for fish_jj_prompt
#
# Usage: fishtape tests/test_fish_jj_prompt.fish

set -g test_dir (mktemp -d)
set -g script_dir (status dirname)/..

# Copy function to tempdir so we test from outside the repo
cp $script_dir/functions/fish_jj_prompt.fish $test_dir/fish_jj_prompt.fish
source $test_dir/fish_jj_prompt.fish

function strip_ansi
    string replace -ra '\e\[[0-9;]*m' '' -- $argv
end

function setup_repo
    set -l repo_dir $test_dir/(random)
    mkdir -p $repo_dir
    cd $repo_dir
    jj git init --no-pager 2>/dev/null
    jj config set --repo user.name "Test User" --no-pager 2>/dev/null
    jj config set --repo user.email "test@example.com" --no-pager 2>/dev/null
    # Ensure @ is authored by configured user
    jj new --no-pager 2>/dev/null
end

function get_prompt
    strip_ansi (fish_jj_prompt)
end

function get_prompt_raw
    fish_jj_prompt | cat -v
end

# --- Non-repo behavior ---

cd $test_dir
fish_jj_prompt 2>/dev/null
@test "returns 1 outside jj repo" $status -eq 1

# --- Non-VCS directory ---

set -l plain_dir $test_dir/(random)_plain
mkdir -p $plain_dir
cd $plain_dir
fish_jj_prompt 2>/dev/null
@test "returns 1 in plain directory" $status -eq 1

# --- Bare git repo (no jj) ---

set -l git_only_dir $test_dir/(random)_git
mkdir -p $git_only_dir
cd $git_only_dir
git init 2>/dev/null 1>/dev/null
fish_jj_prompt 2>/dev/null
@test "returns 1 in bare git repo without jj" $status -eq 1

# --- Disable file ---

setup_repo
touch .disable-jj-prompt
fish_jj_prompt 2>/dev/null
@test "returns 1 with .disable-jj-prompt" $status -eq 1
rm .disable-jj-prompt

# --- Basic empty commit ---

setup_repo
set -l out (get_prompt)

@test "shows @ marker" (string match -q '*(@ *' "$out") $status -eq 0
@test "shows (empty)" (string match -q '*(empty)*' "$out") $status -eq 0
@test "shows (no description set)" (string match -q '*(no description set)*' "$out") $status -eq 0
@test "shows ahead count" (string match -qr '↑[0-9]+' "$out") $status -eq 0

# --- Modified commit ---

setup_repo
echo "content" >file.txt
set -l out (get_prompt)

@test "shows * for modified" (string match -q '* * *' "$out") $status -eq 0

# --- Commit with description ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "Add new feature" 2>/dev/null
set -l out (get_prompt)

@test "shows description" (string match -q '*Add new feature*' "$out") $status -eq 0

# --- Description truncation ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "This is a very long commit description that should be truncated" 2>/dev/null
set -l out (get_prompt)

@test "truncates long description with ellipsis" (string match -q '*This is a very long comm…*' "$out") $status -eq 0

# --- Configurable description length ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "This is a very long commit description" 2>/dev/null

set -g fish_jj_prompt_description_length 10
set -l out (get_prompt)
@test "respects custom description length" (string match -q '*This is a …*' "$out") $status -eq 0

set -g fish_jj_prompt_description_length 0
set -l out (get_prompt)
@test "length 0 disables truncation" (string match -q '*This is a very long commit description*' "$out") $status -eq 0

set -e fish_jj_prompt_description_length

# --- Show description toggle ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "Some description" 2>/dev/null

set -g fish_jj_prompt_show_description false
set -l out (get_prompt)
@test "hides description when false" (string match -q '*Some description*' "$out") $status -ne 0
set -e fish_jj_prompt_show_description

# --- Bookmark at @ ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "work" 2>/dev/null
jj bookmark create --no-pager my-feature -r@ 2>/dev/null
set -l out (get_prompt)

@test "shows bookmark at @" (string match -q '*my-feature*' "$out") $status -eq 0

# --- Ancestor bookmark with depth ---

setup_repo
echo "base" >file.txt
jj desc --no-pager -m "base" 2>/dev/null
jj bookmark create --no-pager my-branch -r@ 2>/dev/null
jj new --no-pager 2>/dev/null
echo "child" >file2.txt
jj desc --no-pager -m "child" 2>/dev/null
set -l out (get_prompt)

@test "shows ancestor bookmark with depth" (string match -qr 'my-branch.*↑1' "$out") $status -eq 0


# --- Ancestor tag with depth ---

setup_repo
echo "base" >file.txt
jj desc --no-pager -m "base" 2>/dev/null
jj bookmark create --no-pager my-branch -r@ 2>/dev/null
jj tag set --no-pager release-2 -r@ 2>/dev/null
jj new --no-pager 2>/dev/null
echo "child" >file2.txt
jj desc --no-pager -m "child" 2>/dev/null
set -l out (get_prompt)

@test "shows ancestor tag with depth by default" (string match -qr 'release-2.*↑2' "$out") $status -eq 0

set -g fish_jj_prompt_show_tags false
set -l out (get_prompt)
@test "hides ancestor tag when false" (string match -q '*release-2*' "$out") $status -ne 0
@test "keeps ancestor bookmark when tags hidden" (string match -qr 'my-branch.*↑2' "$out") $status -eq 0
set -e fish_jj_prompt_show_tags

# --- Multiple commits ahead ---

setup_repo
echo "a" >a.txt
jj desc --no-pager -m "first" 2>/dev/null
jj new --no-pager 2>/dev/null
echo "b" >b.txt
jj desc --no-pager -m "second" 2>/dev/null
jj new --no-pager 2>/dev/null
echo "c" >c.txt
jj desc --no-pager -m "third" 2>/dev/null
set -l out (get_prompt)

@test "shows correct ahead count" (string match -q '*↑4*' "$out") $status -eq 0

# --- Mutable @ is green ---

setup_repo
set -l out_raw (get_prompt_raw)

@test "mutable @ uses green" (string match -q '*[32m@*' "$out_raw") $status -eq 0

# --- Bold toggle ---

setup_repo
echo "content" >file.txt

set -g fish_jj_prompt_bold true
set -l out_raw (get_prompt_raw)
@test "bold on includes bold escape" (string match -q '*[1m*' "$out_raw") $status -eq 0

set -g fish_jj_prompt_bold false
set -l out_raw (get_prompt_raw)
@test "bold off excludes bold escape" (string match -q '*[1m*' "$out_raw") $status -ne 0

set -e fish_jj_prompt_bold

# --- Author display ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "my work" 2>/dev/null
set -l out (get_prompt)

@test "hides author for own commits" (string match -q '*test*' "$out") $status -ne 0

# Create a commit as a different author using env vars for the render
setup_repo
echo "content" >file.txt
jj desc --no-pager -m "some work" 2>/dev/null
# Render prompt as a different user so mine() returns false
set -l out (JJ_USER="Other User" JJ_EMAIL="other@example.com" get_prompt)

@test "shows author when not mine" (string match -q '*test*' "$out") $status -eq 0

# --- Workspace display ---

setup_repo
set -l out (get_prompt)

@test "hides workspace with single workspace" (string match -q '*default@*' "$out") $status -ne 0

set -l ws_dir $test_dir/(random)_ws
jj workspace add --no-pager $ws_dir 2>/dev/null
set -l out (get_prompt)

@test "shows workspace with multiple workspaces" (string match -q '*default@*' "$out") $status -eq 0

# --- Field order ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "test desc" 2>/dev/null
jj bookmark create --no-pager test-bm -r@ 2>/dev/null
set -l out (get_prompt)

# Bookmark should come before description in jj log order
set -l bm_pos (string match -rn 'test-bm' "$out" | string split ' ')[1]
set -l desc_pos (string match -rn 'test desc' "$out" | string split ' ')[1]
@test "bookmark before description (jj log order)" "$bm_pos" -lt "$desc_pos"

# --- Conflict display ---

setup_repo
echo "base" >conflict.txt
jj desc --no-pager -m "base" 2>/dev/null
jj new --no-pager 2>/dev/null
echo "version a" >conflict.txt
jj desc --no-pager -m "version a" 2>/dev/null
jj new --no-pager @- 2>/dev/null
echo "version b" >conflict.txt
jj desc --no-pager -m "version b" 2>/dev/null
jj new --no-pager "children(@-)" 2>/dev/null
set -l out (get_prompt)

@test "shows (conflict) label" (string match -q '*(conflict)*' "$out") $status -eq 0

set -l out_raw (get_prompt_raw)
@test "conflict @ uses dark red" (string match -q '*[38;5;1m@*' "$out_raw") $status -eq 0

# --- Arrows always non-bold ---

setup_repo
echo "content" >file.txt
jj desc --no-pager -m "work" 2>/dev/null
set -g fish_jj_prompt_bold true
set -l out_raw (fish_jj_prompt | string escape)

@test "ahead arrow preceded by nobold" (string match -q '*\e\[22m*↑*' "$out_raw") $status -eq 0

set -e fish_jj_prompt_bold

# --- Parallel paths ahead count ---

setup_repo
echo "base" >file.txt
jj desc --no-pager -m "base" 2>/dev/null
jj new --no-pager 2>/dev/null
echo "a" >a.txt
jj desc --no-pager -m "branch a" 2>/dev/null
jj new --no-pager @- 2>/dev/null
echo "b" >b.txt
jj desc --no-pager -m "branch b" 2>/dev/null
# Merge both branches
jj new --no-pager "children(@-)" 2>/dev/null
jj desc --no-pager -m "merge" 2>/dev/null
set -l out (get_prompt)
# setup_repo empty + base + branch a + branch b + merge = 5 commits ahead
@test "parallel paths all count toward ahead" (string match -q '*↑5*' "$out") $status -eq 0

# --- Cleanup ---

rm -rf $test_dir
