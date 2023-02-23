#!/usr/bin/env bash

# shellcheck disable=SC2155,SC2034,SC2207,SC2317,SC2046

set -xeuo pipefail

script_path() {
	# verify bins are installed
	declare -a bins_arr=(
		asdf
		pip
		jq
		curl
	)

	# TODO: golf to one liner conditional in inner loop
	# add bins to script path
	paths=()
	for i in "${bins_arr[@]}"; do
		if [[ $(command -v "$i" >/dev/null 2>&1; echo "$?") -eq 0 ]]; then
			paths+=($(dirname $(which "$i")))
		else
			echo "Please install/reshim. Missing $i"
			exit 1
		fi
	done

	# replace whitespace with ":" and add to PATH
	export PATH=/usr/bin:/bin:/usr/sbin:/sbin
	export PATH=$(echo "${paths[@]}" | tr ' ' ':'):$PATH
	# echo "$PATH"
}

GH_REPO="https://github.com/ansible/ansible"
# GH_API_REPO="https://api.github.com/repos/ansible/ansible"

fail() {
  echo -e "asdf-ansible: $*"
  exit 1
}

curl_opts=(-fsSL)

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  curl -L -s 'https://pypi.org/pypi/ansible/json' | jq  -r '.releases | keys | .[]' | sort -V
}

list_all_versions() {
  list_github_tags
}

download_release() {
  local version filename url
  version="$1"
  filename="$2"

  url="$GH_REPO/archive/v${version}.tar.gz"

  echo "* Downloading ansible release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-ansible supports release installs only"
  fi

  if [ "$version" == 'latest' ]; then
    version=$(list_github_tags | tail -n1)
    # version=$(curl -s "$GH_API_REPO/releases/latest" | jq '.tag_name' -r | sed 's/^v//')
  fi

  local release_file="$install_path/ansible-$version.tar.gz"
  (
    # mkdir -p "$install_path"
    # download_release "$version" "$release_file"
    # tar -xzf "$release_file" -C "$install_path" --strip-components=1 || fail "Could not extract $release_file"
    # rm "$release_file"
	script_path
    python -m pip install ansible=="$version"

    local tool_cmd
    tool_cmd="$(echo "ansible --version" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    test $("$install_path/bin/$tool_cmd" --version | grep -E '^ansible [0-9a-z\.\-]+' | cut -d ' ' -f 2) == "$version"

    echo "ansible $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing ansible $version."
  )
}
