function chromedriver-update --description 'Install the ChromeDriver that matches the installed Chrome'
    set -l chrome_version (defaults read "/Applications/Google Chrome.app/Contents/Info" CFBundleShortVersionString)
    or return 1
    set -l build (string split . $chrome_version)[1..3]
    set build (string join . $build)

    set -l json (curl -fsSL https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json)
    or return 1
    set -l driver_version (echo $json | jq -r --arg b $build '.builds[$b].version // empty')
    set -l url (echo $json | jq -r --arg b $build '.builds[$b].downloads.chromedriver[]? | select(.platform == "mac-arm64") | .url')
    if test -z "$url"
        echo "No ChromeDriver found for Chrome $chrome_version" >&2
        return 1
    end

    set -l current none
    if command -q chromedriver
        set current (chromedriver --version | string split ' ')[2]
    end
    if test "$current" = "$driver_version"
        echo "ChromeDriver $current already matches Chrome $chrome_version"
        return 0
    end

    set -l tmp (mktemp -d)
    curl -fsSL -o $tmp/cd.zip $url
    and unzip -q $tmp/cd.zip -d $tmp
    and mkdir -p ~/.local/bin
    and mv $tmp/chromedriver-mac-arm64/chromedriver ~/.local/bin/chromedriver
    or begin
        rm -rf $tmp
        return 1
    end
    rm -rf $tmp
    xattr -d com.apple.quarantine ~/.local/bin/chromedriver 2>/dev/null
    echo "ChromeDriver $current -> $driver_version (Chrome $chrome_version)"
end
