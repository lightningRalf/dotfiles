# SSH Agent Management Module
# Provides automatic discovery and connection to SSH agents

# Main connection function
export def connect_ssh_agent [] {
    # Check existing environment
    if (($env.SSH_AUTH_SOCK? | is-not-empty) and 
        ($env.SSH_AUTH_SOCK | path exists)) {
        let test = (ssh-add -l 2>&1 | complete)
        if $test.exit_code != 2 {
            return {status: "existing", socket: $env.SSH_AUTH_SOCK}
        }
    }
    
    # Discover available sockets
    let sockets = (
        ls /tmp 
        | where name =~ "^ssh-" and type == "dir"
        | each { |dir| 
            ls $"/tmp/($dir.name)" 
            | where type == "socket" and name =~ "agent"
            | get name
        }
        | flatten
        | compact
    )
    
    # Test each socket
    for socket in $sockets {
        $env.SSH_AUTH_SOCK = $socket
        let test = (ssh-add -l 2>&1 | complete)
        if $test.exit_code != 2 {
            return {status: "connected", socket: $socket}
        }
    }
    
    return {status: "none", socket: null}
}

# Key loading automation
export def load_ssh_keys [] {
    let keys = [
        {path: "~/.ssh/github_key", host: "github.com"},
        {path: "~/.ssh/id_ed25519", host: "default"},
        {path: "~/.ssh/id_rsa", host: "legacy"}
    ]
    
    let loaded = (ssh-add -l 2>&1 | complete)
    if $loaded.exit_code == 2 {
        print "❌ Cannot connect to SSH agent"
        return
    }
    
    $keys | where { |key| 
        ($key.path | path expand | path exists)
    } | each { |key|
        let expanded = ($key.path | path expand)
        let already_loaded = (
            $loaded.stdout 
            | lines 
            | any { |line| $line | str contains $expanded }
        )
        
        if not $already_loaded {
            print $"Loading key for ($key.host): ($key.path)"
            ssh-add $expanded
        }
    }
}

# Comprehensive SSH diagnostics
export def ssh-status [] {
    print "╔══════════════════════════════════════╗"
    print "║        SSH Agent Status Report       ║"
    print "╚══════════════════════════════════════╝"
    
    # Environment check
    print "\n🔧 Environment Variables:"
    print $"  SSH_AUTH_SOCK: ($env.SSH_AUTH_SOCK? | default 'not set')"
    print $"  SSH_AGENT_PID: ($env.SSH_AGENT_PID? | default 'not set')"
    
    # Socket validation
    if ($env.SSH_AUTH_SOCK? | is-not-empty) {
        if ($env.SSH_AUTH_SOCK | path exists) {
            print "  ✓ Socket file exists"
        } else {
            print "  ❌ Socket file missing"
        }
    }
    
    # Process status
    print "\n🏃 Agent Processes:"
    let agents = (ps | where name == "ssh-agent")
    if ($agents | is-empty) {
        print "  ❌ No agents running"
    } else {
        $agents | each { |agent|
            print $"  PID: ($agent.pid) | Memory: ($agent.mem)"
        }
    }
    
    # Key status
    print "\n🔑 Loaded Keys:"
    let keys = (ssh-add -l 2>&1 | complete)
    if $keys.exit_code == 0 {
        if ($keys.stdout | str trim | is-empty) {
            print "  No keys loaded"
        } else {
            $keys.stdout | lines | each { |line|
                print $"  • ($line)"
            }
        }
    } else if $keys.exit_code == 1 {
        print "  No keys loaded"
    } else {
        print "  ❌ Cannot connect to agent"
    }
}