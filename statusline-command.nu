# Claude Code status line for Nushell (matching Linux style)

def statusline []: string -> string {
    let d = $in | from json

    # Directory with icon
    let cwd = $d.cwd
    let dir = if ($cwd | str starts-with $env.USERPROFILE) {
        $"~($cwd | str replace $env.USERPROFILE '')"
    } else { $cwd | path basename }

    # Git information
    let git_info = try {
        cd $cwd
        let branch = try { ^git branch --show-current | str trim } catch { "" }
        if ($branch | is-empty) {
            ""
        } else {
            # Check dirty status
            let untracked_files = try {
                ^git ls-files --others --exclude-standard | lines | where { |l| not ($l | is-empty) }
            } catch { [] }
            let untracked_count = $untracked_files | length
            let untracked_lines = if $untracked_count > 0 {
                try {
                    $untracked_files | each { |f| open $f | lines | length } | math sum
                } catch { 0 }
            } else { 0 }

            let tracked_dirty = try {
                let diff_exit = (^git diff --quiet | complete).exit_code
                let cached_exit = (^git diff --cached --quiet | complete).exit_code
                $diff_exit != 0 or $cached_exit != 0
            } catch { false }

            let dirty_part = if (not $tracked_dirty) and ($untracked_count == 0) {
                " ✅"
            } else {
                let diff_stats = try { ^git diff --shortstat | str trim } catch { "" }
                let staged_stats = try { ^git diff --cached --shortstat | str trim } catch { "" }

                let parse_stat = { |s, pat|
                    if ($s | is-empty) { 0 } else {
                        try { $s | parse --regex $pat | get 0.val | into int } catch { 0 }
                    }
                }

                let files_w = do $parse_stat $diff_stats '(?P<val>\d+) file'
                let files_s = do $parse_stat $staged_stats '(?P<val>\d+) file'
                let adds_w = do $parse_stat $diff_stats '(?P<val>\d+) insertion'
                let adds_s = do $parse_stat $staged_stats '(?P<val>\d+) insertion'
                let dels_w = do $parse_stat $diff_stats '(?P<val>\d+) deletion'
                let dels_s = do $parse_stat $staged_stats '(?P<val>\d+) deletion'

                let total_files = $files_w + $files_s + $untracked_count
                let total_adds = $adds_w + $adds_s + $untracked_lines
                let total_dels = $dels_w + $dels_s

                let diff_display = (
                    (if $total_files > 0 { $" ($total_files)f" } else { "" })
                    + (if $total_adds > 0 { $" +($total_adds)" } else { "" })
                    + (if $total_dels > 0 { $" -($total_dels)" } else { "" })
                )
                $" ✏️($diff_display)"
            }

            # Check ahead/behind remote
            let sync_part = try {
                let upstream = try { ^git rev-parse --abbrev-ref '@{upstream}' | str trim } catch { "" }
                if ($upstream | is-empty) {
                    ""
                } else {
                    let ahead = try { ^git rev-list --count $"@{upstream}..HEAD" | str trim | into int } catch { 0 }
                    let behind = try { ^git rev-list --count $"HEAD..@{upstream}" | str trim | into int } catch { 0 }
                    (
                        (if $ahead > 0 { $" ↑($ahead)" } else { "" })
                        + (if $behind > 0 { $" ↓($behind)" } else { "" })
                    )
                }
            } catch { "" }

            $" 🌿 ($branch)($dirty_part)($sync_part)"
        }
    } catch { "" }

    # API Latency (cached for 60 seconds)
    let ping_cache = [$env.USERPROFILE, ".claude", "api-ping-cache"] | path join
    let ping_ms = try {
        let use_cache = if ($ping_cache | path exists) {
            let modified = (ls $ping_cache | get 0.modified)
            let age = ((date now) - $modified) | into int | $in / 1_000_000_000
            $age < 60
        } else { false }

        if $use_cache {
            open $ping_cache | str trim | into float | math round
        } else {
            let result = (^curl -o /dev/null -s -w '%{time_connect}' https://api.anthropic.com --connect-timeout 2 | str trim)
            let ms = ($result | into float) * 1000 | math round
            $ms | into string | save -f $ping_cache
            $ms
        }
    } catch { 0 }
    let ping_str = if $ping_ms > 0 { $" | (ansi white)🏓 ($ping_ms)ms(ansi reset)" } else { "" }

    # Build output
    $"(ansi cyan)📁 ($dir)(ansi reset)(ansi green)($git_info)(ansi reset)($ping_str)"
}
