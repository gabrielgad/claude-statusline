# Claude Code status line for Nushell (matching Linux style)

def statusline []: string -> string {
    let d = $in | from json
    
    # Directory with icon
    let cwd = $d.cwd
    let dir = if ($cwd | str starts-with $env.USERPROFILE) {
        $"~($cwd | str replace $env.USERPROFILE '')"
    } else { $cwd | path basename }
    
    # Cost with icon
    let cost = $d.cost?.total_cost_usd? | default 0
    let cost_str = if $cost < 0.01 { "<1¢" } else if $cost < 1 { 
        $"($cost * 100 | math round)¢" 
    } else { 
        $"$($cost | into string --decimals 2)" 
    }
    
    # Get tokens from transcript
    let transcript_path = $d.transcript_path? | default ""
    let tokens = if ($transcript_path != "" and ($transcript_path | path exists)) {
        try {
            let lines = open $transcript_path | lines | reverse | first 100
            let usage_line = $lines | where { |line|
                let p = try { $line | from json } catch { {} }
                (($p | get -o message.usage) != null) and (($p | get -o isSidechain | default false) == false)
            } | first
            let entry = $usage_line | from json
            let u = $entry.message.usage
            {
                inp: ($u | get -o input_tokens | default 0),
                out: ($u | get -o output_tokens | default 0),
                cache_read: ($u | get -o cache_read_input_tokens | default 0),
                cache_create: ($u | get -o cache_creation_input_tokens | default 0)
            }
        } catch { { inp: 0, out: 0, cache_read: 0, cache_create: 0 } }
    } else { { inp: 0, out: 0, cache_read: 0, cache_create: 0 } }
    
    let fmt = { |n| if $n >= 1000000 { $"(($n / 1000000) | math round --precision 1)M" } else if $n >= 1000 { $"($n / 1000 | math round)K" } else { $"($n)" } }
    
    # Context calculation
    let ctx_total = $tokens.inp + $tokens.cache_read + $tokens.cache_create
    let ctx_size = $d.context_window?.context_window_size? | default 200000
    let pct = (($ctx_total / $ctx_size) * 100) | math round
    let pct_color = if $pct >= 80 { (ansi red) } else if $pct >= 50 { (ansi yellow) } else { (ansi green) }
    let ctx_display = do $fmt $ctx_total
    
    # Model short name
    let model = $d.model.display_name
    let model_short = if ($model | str contains "Opus") { "O" } else if ($model | str contains "Sonnet") { "S" } else if ($model | str contains "Haiku") { "H" } else { "?" }
    
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
    $"(ansi cyan)📁 ($dir)(ansi reset) | (ansi magenta)🤖 ($model_short)(ansi reset) | (ansi yellow)💰 ($cost_str)(ansi reset) | ($pct_color)🧠 ($ctx_display) ($pct)%(ansi reset) | (ansi blue)📊 (do $fmt $tokens.inp)↑(do $fmt $tokens.out)↓(ansi reset) (ansi cyan)⚡(do $fmt $tokens.cache_create)↑(do $fmt $tokens.cache_read)↓(ansi reset)($ping_str)"
}
