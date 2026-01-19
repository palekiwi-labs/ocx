export def get-local-image-tags []: nothing -> list<string> {
    let result = docker images localhost/ocx --format "{{.Tag}}" | complete

    if $result.exit_code != 0 {
        return []
    }

    if ($result.stdout | str trim) == "" {
        return []
    }

    $result.stdout | lines
}

export def parse-semantic-versions [tags: list<string>]: nothing -> list<string> {
    $tags
    | where { |tag| $tag != "latest" }
    | where { |tag|
        $tag =~ '^\d+\.\d+\.\d+$'
    }
}

export def get-local-semantic-versions []: nothing -> list<string> {
    let tags = (get-local-image-tags)
    parse-semantic-versions $tags
}
