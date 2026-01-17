export def resolve-user [config: record] {
    let username = if $config.username == null {
        $env.USER? | default "user"
    } else {
        $config.username
    }
    
    let uid = if $config.uid == null {
        (id -u | str trim | into int)
    } else {
        $config.uid
    }
    
    let gid = if $config.gid == null {
        (id -g | str trim | into int)
    } else {
        $config.gid
    }
    
    {
        username: $username
        uid: $uid
        gid: $gid
    }
}
