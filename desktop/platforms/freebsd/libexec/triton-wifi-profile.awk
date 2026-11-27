# Remove a Triton-owned network block with this SSID marker. Marker matching
# ignores indentation because wpa_supplicant files conventionally indent it.
{
    if (mode == "psk") {
        if ($1 ~ /^psk=/) {
            value = $1
            sub(/^psk=/, "", value)
            if (length(value) == 64 && value !~ /[^0-9a-fA-F]/) {
                print value
                exit
            }
        }
        next
    }
    if ($0 ~ /^[[:space:]]*network=[[:space:]]*\{/) {
        in_block = 1
        block = $0 ORS
        remove = 0
        next
    }
    if (in_block) {
        block = block $0 ORS
        normalized = $0
        sub(/^[[:space:]]+/, "", normalized)
        if (normalized == target) remove = 1
        if ($0 ~ /^[[:space:]]*\}/) {
            if (!remove) printf "%s", block
            in_block = 0
            block = ""
        }
        next
    }
    print
}
END { if (mode != "psk" && in_block && !remove) printf "%s", block }
