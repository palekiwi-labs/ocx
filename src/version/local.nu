use ../docker_tools/utils.nu get-image-name-base

export def get-local-image-tags [cfg: record]: nothing -> list<string> {
    let image_name = (get-image-name-base $cfg)
    let result = docker images $image_name --format "{{.Tag}}" | complete


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

export def get-local-semantic-versions [cfg: record]: nothing -> list<string> {
    let tags = (get-local-image-tags $cfg)
    parse-semantic-versions $tags
}
