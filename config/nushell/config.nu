# Enhanced Nushell Configuration - Stage 2
# Location: ~/.config/nushell/config.nu

# ===== Core Environment Loading =====
source ~/.config/nushell/env.nu

# ===== Structured Data Aliases =====

# Enhanced ls with better defaults
alias ls = ls --full-paths=false
alias ll = ls -la
alias la = ls -a
alias lt = ls -la | sort-by modified | reverse

# Git status with structured output
def gss [] {
    let status = (git status --porcelain | lines)
    let changes = ($status | parse "{type} {file}" | 
        group-by type | 
        transpose key value |
        each { |it| 
            {
                status: $it.key
                count: ($it.value | length)
                files: ($it.value | get file)
            }
        }
    )
    
    if ($changes | is-empty) {
        print "✓ Working directory clean"
    } else {
        print "Git Status Summary:"
        $changes | table
    }
}

# System information dashboard
def sysinfo [] {
    print $"(ansi yellow_bold)System Information(ansi reset)"
    print $"═══════════════════════════════════════"
    
    let host_info = (sys | get host)
    print $"(ansi cyan)Hostname:(ansi reset)     ($host_info.hostname)"
    print $"(ansi cyan)OS:(ansi reset)           ($host_info.name) ($host_info.os_version)"
    print $"(ansi cyan)Kernel:(ansi reset)       ($host_info.kernel_version)"
    print $"(ansi cyan)Uptime:(ansi reset)       ($host_info.uptime)"
    
    print ""
    let cpu_info = (sys | get cpu | first)
    print $"(ansi cyan)CPU:(ansi reset)          ($cpu_info.brand)"
    print $"(ansi cyan)Cores:(ansi reset)        (sys | get cpu | length)"
    
    print ""
    let mem_info = (sys | get mem)
    let mem_used_pct = (($mem_info.used / $mem_info.total) * 100 | math round -p 1)
    print $"(ansi cyan)Memory:(ansi reset)       ($mem_info.used | format filesize) / ($mem_info.total | format filesize) \(($mem_used_pct)%\)"
    
    print ""
    let disk_info = (sys | get disks | where mount == "/" | first)
    let disk_used_pct = (($disk_info.used / $disk_info.total) * 100 | math round -p 1)
    print $"(ansi cyan)Disk \(root\):(ansi reset)  ($disk_info.used | format filesize) / ($disk_info.total | format filesize) \(($disk_used_pct)%\)"
}

# ===== Navigation Enhancements =====

# Quick directory jumping with memory
def --env cdh [index?: int] {
    if $index == null {
        # Show directory history
        let dirs = (shells | enumerate | each { |it| 
            $"($it.index): ($it.item.path)"
        })
        $dirs | str join "\n" | print
    } else {
        # Jump to specific history index
        enter $index
    }
}

# Project directory manager
def --env proj [name?: string] {
    let projects_dir = $"($env.HOME)/projects"
    
    if $name == null {
        # List projects
        ls $projects_dir | where type == "dir" | get name | path basename
    } else {
        # Navigate to project
        let project_path = $"($projects_dir)/($name)"
        if ($project_path | path exists) {
            cd $project_path
            print $"📁 Entered project: ($name)"
            
            # Auto-activate virtual environment if exists
            let venv_paths = ["venv" ".venv" "env" ".env"]
            for venv in $venv_paths {
                let venv_path = $"($project_path)/($venv)"
                if ($venv_path | path exists) {
                    print $"🐍 Found virtual environment: ($venv)"
                    break
                }
            }
        } else {
            print $"Project not found: ($name)"
        }
    }
}

# ===== File Operations =====

# Safe move with confirmation for overwrites
def mv-safe [source: path, dest: path] {
    if ($dest | path exists) {
        let response = (input $"File exists: ($dest). Overwrite? [y/N] ")
        if $response == "y" {
            mv -f $source $dest
            print $"✓ Moved ($source) to ($dest)"
        } else {
            print "Operation cancelled"
        }
    } else {
        mv $source $dest
        print $"✓ Moved ($source) to ($dest)"
    }
}

# Batch rename with pattern
def rename-batch [pattern: string, replacement: string] {
    ls | where name =~ $pattern | each { |file|
        let new_name = ($file.name | str replace $pattern $replacement)
        if $new_name != $file.name {
            mv $file.name $new_name
            print $"Renamed: ($file.name) → ($new_name)"
        }
    }
}

# ===== Git Helpers =====

# Interactive git add
def "git add-interactive" [] {
    let changes = (git status --porcelain | lines | parse "{status} {file}")
    
    if ($changes | is-empty) {
        print "No changes to add"
        return
    }
    
    print "Select files to stage:"
    let selected = ($changes | 
        get file | 
        input list --multi
    )
    
    if ($selected | is-empty) {
        print "No files selected"
    } else {
        $selected | each { |file| git add $file }
        print $"✓ Staged ($selected | length) files"
    }
}

# Show git log with graph
def glog [--oneline (-o), --max (-n): int = 20] {
    if $oneline {
        git log --graph --oneline --decorate --all -n $max
    } else {
        git log --graph --pretty=format:'%C(yellow)%h%C(reset) - %C(green)(%cr)%C(reset) %s %C(blue)<%an>%C(reset)' --abbrev-commit --all -n $max
    }
}

# ===== Development Helpers =====

# Find TODO comments in code
def find-todos [path?: path] {
    let search_path = if $path == null { "." } else { $path }
    
    rg -i "todo|fixme|hack|bug" $search_path -n --type-list | lines | parse "{file}:{line}:{match}" | 
        group-by file | 
        transpose file matches |
        each { |it|
            {
                file: $it.file
                count: ($it.matches | length)
                items: $it.matches
            }
        } | 
        sort-by count --reverse
}

# Quick HTTP server
def serve [port?: int] {
    let port = if $port == null { 8000 } else { $port }
    print $"Starting HTTP server on port ($port)..."
    python -m http.server $port
}

# ===== Data Processing =====

# CSV preview with stats
def csv-preview [file: path, --rows (-n): int = 10] {
    let data = (open $file)
    
    print $"File: ($file)"
    print $"Rows: ($data | length)"
    print $"Columns: ($data | columns | length)"
    print ""
    print "Column Statistics:"
    
    $data | columns | each { |col|
        let values = ($data | get $col)
        let numeric = ($values | where { |v| $v | describe | str contains "int\|float" } | length)
        
        {
            column: $col
            type: (if $numeric > 0 { "numeric" } else { "text" })
            nulls: ($values | where { |v| $v == null } | length)
            unique: ($values | uniq | length)
        }
    } | table
    
    print ""
    print $"First ($rows) rows:"
    $data | first $rows | table
}

# ===== Custom Completions =====

# Git branch completion
def "nu-complete git branches" [] {
    git branch -a | lines | str trim | str replace '\* ' '' | uniq
}

# Project completion
def "nu-complete projects" [] {
    ls ~/projects | where type == "dir" | get name | path basename
}

# ===== Key Bindings Configuration =====
$env.config = ($env.config | merge {
    keybindings: [
        {
            name: completion_menu
            modifier: none
            keycode: tab
            mode: [emacs vi_normal vi_insert]
            event: {
                until: [
                    { send: menu name: completion_menu }
                    { send: menunext }
                ]
            }
        }
        {
            name: history_menu
            modifier: control
            keycode: char_r
            mode: [emacs vi_insert]
            event: { send: menu name: history_menu }
        }
        {
            name: help_menu
            modifier: control
            keycode: char_q
            mode: [emacs vi_insert vi_normal]
            event: { send: menu name: help_menu }
        }
        # Quick directory navigation
        {
            name: parent_dir
            modifier: alt
            keycode: up
            mode: [emacs vi_normal vi_insert]
            event: { send: executehostcommand cmd: "cd .." }
        }
        {
            name: previous_dir
            modifier: alt
            keycode: left
            mode: [emacs vi_normal vi_insert]
            event: { send: executehostcommand cmd: "cd -" }
        }
    ]
    
    menus: [
        {
            name: completion_menu
            only_buffer_difference: false
            marker: "| "
            type: {
                layout: columnar
                columns: 4
                col_width: 20
                col_padding: 2
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
        {
            name: history_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
    ]
})

# ===== Hooks for Enhanced Behavior =====
$env.config = ($env.config | merge {
    hooks: {
        pre_prompt: [{
            # Update terminal title with current directory
            let dir = (pwd | path basename)
            print -n $"(ansi title)($dir) - Nushell(ansi st)"
        }]
        
        env_change: {
            PWD: [{|before, after|
                # Show brief directory info when changing
                let file_count = (ls | length)
                let dir_count = (ls | where type == "dir" | length)
                let size = (ls | get size | math sum | format filesize)
                
                print $"📁 ($after | path basename): ($file_count) items \(($dir_count) dirs\), ($size) total"
            }]
        }
    }
})

# ===== Environment Integration =====

# Source additional configurations if they exist
let local_config = $"($env.HOME)/.config/nushell/local.nu"
if ($local_config | path exists) {
    source $local_config
}

# Source work-specific configuration
let work_config = $"($env.HOME)/.config/nushell/work.nu"
if ($work_config | path exists) {
    source $work_config
}

# ===== Welcome and Status =====
if $env.TERM != "dumb" {
    print $"(ansi green_bold)Nushell(ansi reset) (ansi blue)(version)(ansi reset) - Stage 2 Enhanced Configuration"
    
    # Quick status check
    let git_repos = (ls ~ | where name =~ "\.git$" | length)
    let cargo_installed = (which cargo | complete | get exit_code) == 0
    let docker_running = (which docker | complete | get exit_code) == 0 and (docker ps | complete | get exit_code) == 0
    
    print $"Status: 🏠 ($env.HOME | path basename) | 📚 ($git_repos) repos | 🦀 Rust: (if $cargo_installed { '✓' } else { '✗' }) | 🐋 Docker: (if $docker_running { '✓' } else { '✗' })"
    print ""
}