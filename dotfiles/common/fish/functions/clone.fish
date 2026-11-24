function clone --description "Clone a git repository"
    if test (count $argv) -lt 1
        echo "usage: clone repository [git-clone-options]" >&2
        return 2
    end

    set -l repo $argv[1]

    # URL completa (https://, ssh://, git@host:...) -> se usa tal cual
    if string match -qr '://|^[^/]+@[^:]+:' -- $repo
        git clone $repo $argv[2..-1]
    # Atajo usuario/repo -> GitHub
    else if string match -qr '^[^/]+/[^/]+$' -- $repo
        git clone https://github.com/$repo.git $argv[2..-1]
    # Solo nombre del repo -> tu cuenta de GitHub
    else
        git clone https://github.com/WakeUpFern/$repo.git $argv[2..-1]
    end
end
