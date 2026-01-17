const GITHUB_API_BASE = "https://api.github.com/repos/anomalyco/opencode/releases"

export def fetch-latest-release [] {
    const API_URL = $"($GITHUB_API_BASE)/latest"

    try {
        let response = http get $API_URL

        if $response == null {
            return null
        }

        let tag_name = $response.tag_name? | default null
        let body = $response.body? | default null
        let published_at = $response.published_at? | default null

        if $tag_name == null {
            return null
        }

        {
            version: $tag_name,
            notes: $body,
            published_at: $published_at
        }
    } catch { |err|
        handle-github-error $err
    }
}

export def fetch-release-notes [version: string] {
    let api_url = $"($GITHUB_API_BASE)/tags/($version)"

    try {
        let response = http get $api_url

        if $response == null {
            return null
        }

        $response.body? | default null
    } catch { |err|
        handle-github-error $err
    }
}

def handle-github-error [err]: nothing -> nothing {
    let msg = $err.msg | str downcase

    if ($msg | str contains "403") {
        eprintln "GitHub API rate limit exceeded. Using cached version if available."
        return null
    }

    if ($msg | str contains "404") {
        eprintln "GitHub API: Repository not found (404). The repository may have moved."
        return null
    }

    if ($msg | str contains "5") or ($msg | str contains "502") or ($msg | str contains "503") {
        eprintln "GitHub API: Server error (5xx). Please try again later."
        return null
    }

    if ($msg | str contains "timeout") or ($msg | str contains "timed out") {
        eprintln "Request to GitHub timed out. Check your network connection."
        return null
    }

    if ($msg | str contains "connection") or ($msg | str contains "dns") or ($msg | str contains "resolve") {
        eprintln "Network error: Cannot connect to GitHub. Check your internet connection."
        return null
    }

    if ($msg | str contains "tls") or ($msg | str contains "ssl") or ($msg | str contains "certificate") {
        eprintln "TLS/SSL error: Certificate validation failed. Check your system time and certificates."
        return null
    }

    eprintln $"GitHub API error: ($err.msg)"
    null
}
