#!/usr/bin/env bash
set -euo pipefail

# setup.sh delegates the environment to merry-setup, so the SDK download, checksum verification,
# host validation, tool activation and Trunk launcher are covered by that project's own suite.
# What this repository still owns is the delegation: the pin, how the implementation is fetched,
# and the options this project selects. Those are what this test drives.

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly SETUP_SCRIPT="${REPOSITORY_ROOT}/setup.sh"
TEST_FIXTURE=''

cleanup() {
	if [[ -n ${TEST_FIXTURE} && -d ${TEST_FIXTURE} ]]; then
		rm -rf -- "${TEST_FIXTURE}"
	fi
}

trap cleanup EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

assert_contains() {
	local expected=$1
	local file_path=$2
	grep -Fqx -- "${expected}" "${file_path}" || fail "Expected ${expected} in ${file_path}."
}

assert_absent() {
	local unexpected=$1
	local file_path=$2
	if grep -Fqx -- "${unexpected}" "${file_path}"; then
		fail "Did not expect ${unexpected} in ${file_path}."
	fi
}

pinned_revision() {
	sed -n 's/^readonly MERRY_SETUP_REVISION=\([0-9a-f]*\)$/\1/p' "${SETUP_SCRIPT}" | head -n 1
}

# A curl that records the request and writes a runnable file, standing in for the real download.
write_fake_curl() {
	local fake_bin=$1

	mkdir -p -- "${fake_bin}"
	cat >"${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
output_path=''
while [[ $# -gt 0 ]]; do
	case "$1" in
	--output)
		output_path=$2
		shift 2
		;;
	http*)
		printf 'requested %s\n' "$1" >>"${CURL_LOG}"
		shift
		;;
	*) shift ;;
	esac
done
[[ -n ${output_path} ]] || exit 2
[[ ${DOWNLOAD_FAILS:-0} != 1 ]] || exit 22
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@" >>"${ARGV_LOG}"' >"${output_path}"
EOF
	chmod 0755 "${fake_bin}/curl"
}

# A recording stub in place of the downloaded implementation, so the wrapper skips the download and
# the exact argv it builds is captured.
plant_merry_setup() {
	local home=$1
	local revision
	local target

	revision="$(pinned_revision)"
	target="${home}/.merry-setup/bin/merry-setup-${revision}"

	mkdir -p -- "${home}/.merry-setup/bin"
	cat >"${target}" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"${ARGV_LOG}"
STUB
	chmod 0755 "${target}"
}

create_test_fixture() {
	cleanup
	TEST_FIXTURE="$(mktemp -d)"
	write_fake_curl "${TEST_FIXTURE}/fake-bin"
	: >"${TEST_FIXTURE}/argv.log"
	: >"${TEST_FIXTURE}/curl.log"
}

run_setup() {
	local home=$1
	shift

	mkdir -p -- "${home}"
	env -u PUB_CACHE \
		HOME="${home}" \
		PATH="${TEST_FIXTURE}/fake-bin:${PATH}" \
		ARGV_LOG="${TEST_FIXTURE}/argv.log" \
		CURL_LOG="${TEST_FIXTURE}/curl.log" \
		"$@" \
		bash "${SETUP_SCRIPT}"
}

test_pins_an_immutable_revision() {
	local revision
	revision="$(pinned_revision)"

	# A movable reference would silently change what every container installs.
	[[ ${revision} =~ ^[0-9a-f]{40}$ ]] ||
		fail "MERRY_SETUP_REVISION must be a full commit SHA, found '${revision}'."
}

test_downloads_from_the_pinned_revision() {
	local home revision
	revision="$(pinned_revision)"

	create_test_fixture
	home="${TEST_FIXTURE}/home-download"
	run_setup "${home}"

	assert_contains \
		"requested https://raw.githubusercontent.com/AndrewDongminYoo/merry-setup/${revision}/bin/merry-setup" \
		"${TEST_FIXTURE}/curl.log"
	[[ -x ${home}/.merry-setup/bin/merry-setup-${revision} ]] ||
		fail 'The downloaded implementation was not published as an executable.'
}

test_failed_download_leaves_nothing_reusable() {
	local home revision command_exit
	revision="$(pinned_revision)"

	create_test_fixture
	home="${TEST_FIXTURE}/home-failed"

	set +e
	run_setup "${home}" DOWNLOAD_FAILS=1 >/dev/null 2>&1
	command_exit=$?
	set -e

	if [[ ${command_exit} -eq 0 ]]; then
		fail 'Expected a failed download to stop the setup.'
	fi
	[[ ! -e ${home}/.merry-setup/bin/merry-setup-${revision} ]] ||
		fail 'A failed download must not publish an executable.'
	if compgen -G "${home}/.merry-setup/bin/merry-setup-${revision}.*" >/dev/null; then
		fail 'A failed download left a staged file behind.'
	fi
}

test_runs_with_this_projects_options() {
	local home
	local argv_log

	create_test_fixture
	home="${TEST_FIXTURE}/home-cached"
	mkdir -p -- "${home}"
	plant_merry_setup "${home}"
	run_setup "${home}"

	argv_log="${TEST_FIXTURE}/argv.log"
	[[ ! -s ${TEST_FIXTURE}/curl.log ]] ||
		fail 'A cached implementation should not be downloaded again.'

	assert_contains 'setup' "${argv_log}"
	assert_contains '--sdk' "${argv_log}"
	assert_contains 'flutter' "${argv_log}"
	assert_contains '--bootstrap' "${argv_log}"
	assert_contains 'melos' "${argv_log}"
	assert_contains '--persist-path' "${argv_log}"
	assert_contains 'bashrc' "${argv_log}"
	assert_contains '--dart-package' "${argv_log}"
	assert_contains 'flutterfire_cli' "${argv_log}"
	assert_contains '--precache' "${argv_log}"
	assert_contains 'linux,web' "${argv_log}"

	# merry-setup activates Merry by default and rejects it as a package name, so naming it here
	# would turn a working default into a hard failure.
	assert_absent 'merry' "${argv_log}"
}

case "${1:-all}" in
all)
	test_pins_an_immutable_revision
	test_downloads_from_the_pinned_revision
	test_failed_download_leaves_nothing_reusable
	test_runs_with_this_projects_options
	;;
pin) test_pins_an_immutable_revision ;;
download) test_downloads_from_the_pinned_revision ;;
failure) test_failed_download_leaves_nothing_reusable ;;
options) test_runs_with_this_projects_options ;;
*)
	echo "usage: $0 [all|pin|download|failure|options]" >&2
	exit 2
	;;
esac

echo 'setup.sh delegation checks passed.'
