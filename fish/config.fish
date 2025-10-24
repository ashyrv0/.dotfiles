if status is-interactive
    # Load pywal colors if available
    if test -f ~/.cache/wal/colors.fish
        source ~/.cache/wal/colors.fish
    end

    # Starship prompt
    starship init fish | source

    # Extra sequences (caelestia)
    cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    set -Ux PATH $HOME/.local/bin $PATH

    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
end
