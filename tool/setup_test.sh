#!/usr/bin/env bash
set -euo pipefail

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

write_fake_commands() {
	local fake_bin=$1

	mkdir -p "${fake_bin}"

	cat >"${fake_bin}/uname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
-s) echo Linux ;;
-m) echo "${TEST_ARCH}" ;;
*) exit 1 ;;
esac
EOF

	cat >"${fake_bin}/python3" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '3.47.1|stable/linux/flutter_linux_3.47.1-stable.tar.xz|unused'
EOF

	cat >"${fake_bin}/git" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == 'ls-files' ]]; then
	[[ ${PWD} == "${EXPECTED_REPOSITORY}" ]]
	exit
fi
exit 0
EOF

	cat >"${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
output_path=''
while [[ $# -gt 0 ]]; do
	if [[ $1 == '--output' ]]; then
		output_path=$2
		shift 2
		continue
	fi
	shift
done
[[ -n ${output_path} ]] || exit 1
printf '#!/usr/bin/env bash\nexit 0\n' >"${output_path}"
chmod 0755 "${output_path}"
EOF

	chmod 0755 "${fake_bin}/uname" "${fake_bin}/python3" "${fake_bin}/git" "${fake_bin}/curl"
}

write_fake_sdk() {
	local home_path=$1

	mkdir -p "${home_path}/flutter/bin" "${home_path}/.pub-cache/bin"

	cat >"${home_path}/flutter/bin/flutter" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
--version) printf '%s\n' 'Flutter 3.47.1' ;;
precache) ;;
pub) ;;
*) exit 1 ;;
esac
EOF

	cat >"${home_path}/flutter/bin/dart" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == '--version' ]]; then
	printf '%s\n' 'Dart SDK version: 3.11.0'
	exit 0
fi
[[ ${1:-} == 'pub' && ${2:-} == 'global' && ${3:-} == 'activate' ]] || exit 1
printf 'activate:%s\n' "${4:-}" >>"${TEST_LOG}"
EOF

	cat >"${home_path}/.pub-cache/bin/melos" <<'EOF'
#!/usr/bin/env bash
printf 'melos:%s\n' "${PWD}" >>"${TEST_LOG}"
EOF

	chmod 0755 "${home_path}/flutter/bin/flutter" "${home_path}/flutter/bin/dart" "${home_path}/.pub-cache/bin/melos"
}

create_fixture() {
	local fixture_path=$1

	mkdir -p "${fixture_path}/repository" "${fixture_path}/caller"
	cp "${SETUP_SCRIPT}" "${fixture_path}/repository/setup.sh"
	touch "${fixture_path}/repository/pubspec.yaml" "${fixture_path}/repository/pubspec.lock"
	write_fake_commands "${fixture_path}/fake-bin"
	write_fake_sdk "${fixture_path}/home"
}

create_test_fixture() {
	cleanup
	TEST_FIXTURE="$(mktemp -d)"
	create_fixture "${TEST_FIXTURE}"
}

run_setup() {
	local fixture_path=$1
	local host_arch=$2
	local output_path=$3
	local repository_path
	repository_path="$(cd "${fixture_path}/repository" && pwd -P)"

	(
		cd "${fixture_path}/caller"
		HOME="${fixture_path}/home" \
			PUB_CACHE="${fixture_path}/home/.pub-cache" \
			PATH="${fixture_path}/fake-bin:${PATH}" \
			TEST_ARCH="${host_arch}" \
			TEST_LOG="${fixture_path}/log" \
			EXPECTED_REPOSITORY="${repository_path}" \
			"${fixture_path}/repository/setup.sh"
	) >"${output_path}" 2>&1
}

test_bootstraps_from_script_repository() {
	local expected_repository

	create_test_fixture
	run_setup "${TEST_FIXTURE}" x86_64 "${TEST_FIXTURE}/output"
	expected_repository="$(cd "${TEST_FIXTURE}/repository" && pwd -P)"
	assert_contains "melos:${expected_repository}" "${TEST_FIXTURE}/log"
}

test_installs_flutterfire_cli() {
	create_test_fixture
	run_setup "${TEST_FIXTURE}" x86_64 "${TEST_FIXTURE}/output"
	assert_contains 'activate:flutterfire_cli' "${TEST_FIXTURE}/log"
}

test_rejects_unsupported_arm64() {
	local command_exit

	create_test_fixture
	set +e
	run_setup "${TEST_FIXTURE}" arm64 "${TEST_FIXTURE}/output"
	command_exit=$?
	set -e
	if [[ ${command_exit} -eq 0 ]]; then
		fail 'Expected ARM64 setup to fail.'
	fi
	assert_contains 'ERROR: Cloud setup supports only Linux x64 hosts.' "${TEST_FIXTURE}/output"
}

case "${1:-all}" in
all)
	test_bootstraps_from_script_repository
	test_installs_flutterfire_cli
	test_rejects_unsupported_arm64
	;;
bootstrap) test_bootstraps_from_script_repository ;;
flutterfire) test_installs_flutterfire_cli ;;
arm64) test_rejects_unsupported_arm64 ;;
*)
	echo "usage: $0 [all|bootstrap|flutterfire|arm64]" >&2
	exit 2
	;;
esac
