#!/usr/bin/env bats

setup_file() {
  export SCRIPT_DIR="${BATS_TEST_DIRNAME}"
  export REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  export ACTION_FILE="${REPO_ROOT}/actions/semantic_versioning/action.yml"
  export ACTION_RUN_SCRIPT="${BATS_FILE_TMPDIR}/calculate_version_from_action.sh"

  # Parse the run-block from GitHub Action once for all tests in this file
  yq '.runs.steps[] | select(.id == "calculate-version") | .run' "${ACTION_FILE}" > "${ACTION_RUN_SCRIPT}"
  chmod +x "${ACTION_RUN_SCRIPT}"
}

setup() {
  export COMMIT_COUNTER=0
  export LAST_COMMIT_SHA=""
}

# Helper functions

commit_msg() {
  local msg="$1"
  COMMIT_COUNTER=$((COMMIT_COUNTER + 1))
  mkdir -p commits
  printf "%s\n" "${msg}" >"commits/${COMMIT_COUNTER}.txt"
  git add "commits/${COMMIT_COUNTER}.txt"
  git commit -q -m "${msg}"
  LAST_COMMIT_SHA=$(git rev-parse HEAD)
}

cherry_pick_commit() {
  local sha="$1"
  git cherry-pick -x --no-edit "${sha}" >/dev/null
}

init_dummy_repo() {
  local repo_dir="$1"
  mkdir -p "${repo_dir}"
  cd "${repo_dir}"
  git init -q --initial-branch=development
  git config user.name "dummy"
  git config user.email "dummy@example.com"

  # HACK: add a local remote so `git fetch --tags` inside the action doesn't fail
  git remote add origin "$(pwd)"
}

read_output_key() {
  local key="$1"
  grep "^${key}=" "${BATS_TEST_TMPDIR}/calc_output.txt" | tail -1 | cut -d= -f2-
}

run_calc() {
  local promote="$1"

  local GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/calc_output.txt"
  local GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/calc_summary.md"

  : >"${GITHUB_OUTPUT}"
  : >"${GITHUB_STEP_SUMMARY}"

  INPUT_PROMOTE="${promote}" \
  GITHUB_OUTPUT="${GITHUB_OUTPUT}" \
  GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY}" \
  run bash "${ACTION_RUN_SCRIPT}"

  if [ "$status" -ne 0 ]; then
    echo "Action script failed with status $status:" >&3
    echo "$output" >&3
    return 1
  fi

  export CALC_NEXT_VERSION=$(read_output_key "next-version")
  export CALC_IS_RELEASE_CANDIDATE=$(read_output_key "is-release-candidate")
  export CALC_IS_RELEASE=$(read_output_key "is-release")
  export CALC_IS_LATEST=$(read_output_key "is-latest")
  export CALC_RELEASE_LINE=$(read_output_key "release-line")
  export CALC_CHANGELOG_MODE=$(read_output_key "changelog-mode")
}

assert_calc() {
  local scenario="$1"
  local branch="$2"
  local promote="$3"
  local expected_next="$4"
  local expected_is_rc="$5"
  local expected_is_release="$6"
  local expected_is_latest="$7"
  local expected_release_line="$8"
  local expected_changelog_mode="$9"

  git checkout -q "${branch}"
  run_calc "${promote}"

  # Bats assertions
  [ "${expected_next}" = "${CALC_NEXT_VERSION}" ] || { echo "FAIL ${scenario}: Expected next-version '${expected_next}', got '${CALC_NEXT_VERSION}'" >&3; return 1; }
  [ "${expected_is_rc}" = "${CALC_IS_RELEASE_CANDIDATE}" ] || { echo "FAIL ${scenario}: Expected is-release-candidate '${expected_is_rc}', got '${CALC_IS_RELEASE_CANDIDATE}'" >&3; return 1; }
  [ "${expected_is_release}" = "${CALC_IS_RELEASE}" ] || { echo "FAIL ${scenario}: Expected is-release '${expected_is_release}', got '${CALC_IS_RELEASE}'" >&3; return 1; }
  [ "${expected_is_latest}" = "${CALC_IS_LATEST}" ] || { echo "FAIL ${scenario}: Expected is-latest '${expected_is_latest}', got '${CALC_IS_LATEST}'" >&3; return 1; }
  [ "${expected_release_line}" = "${CALC_RELEASE_LINE}" ] || { echo "FAIL ${scenario}: Expected release-line '${expected_release_line}', got '${CALC_RELEASE_LINE}'" >&3; return 1; }
  [ "${expected_changelog_mode}" = "${CALC_CHANGELOG_MODE}" ] || { echo "FAIL ${scenario}: Expected changelog-mode '${expected_changelog_mode}', got '${CALC_CHANGELOG_MODE}'" >&3; return 1; }
}


# ==========================================
#                  TESTS
# ==========================================

@test "Full lifecycle scenarios (0-16)" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/full-lifecycle"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "false" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "false" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.0
  assert_calc "S2" "release-1.0" "false" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.0

  git checkout -q development
  commit_msg "fix: 1"
  local sha_fix1="${LAST_COMMIT_SHA}"
  assert_calc "S3" "development" "false" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix1}"
  assert_calc "S4" "release-1.0" "false" "1.0.0-rc.1" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.1

  assert_calc "S5" "release-1.0" "true" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development
  commit_msg "feat: 2"
  commit_msg "fix: 2"
  local sha_fix2="${LAST_COMMIT_SHA}"
  assert_calc "S6" "development" "false" "1.1.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix2}"
  assert_calc "S7" "release-1.0" "false" "1.0.1" "false" "true" "true" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.1

  git checkout -q development
  git checkout -q -b release-1.1
  assert_calc "S8" "release-1.1" "false" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0-rc.0

  assert_calc "S9" "release-1.1" "true" "1.1.0" "false" "true" "true" "1.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0

  git checkout -q development
  commit_msg "feat: 3"
  assert_calc "S10" "development" "false" "1.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.2
  assert_calc "S11" "release-1.2" "false" "1.2.0-rc.0" "true" "false" "false" "1.2" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0-rc.0

  assert_calc "S12" "release-1.2" "true" "1.2.0" "false" "true" "true" "1.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0

  git checkout -q development
  commit_msg "fix: 3"
  local sha_fix3="${LAST_COMMIT_SHA}"
  commit_msg "fix: 4"
  local sha_fix4="${LAST_COMMIT_SHA}"
  commit_msg "fix: 5"
  local sha_fix5="${LAST_COMMIT_SHA}"
  assert_calc "S13" "development" "false" "1.3.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q release-1.1
  cherry_pick_commit "${sha_fix3}"
  assert_calc "S14" "release-1.1" "false" "1.1.1" "false" "true" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.1

  git checkout -q release-1.2
  cherry_pick_commit "${sha_fix4}"
  assert_calc "S15" "release-1.2" "false" "1.2.1" "false" "true" "true" "1.2" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.2.1

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix5}"
  assert_calc "S16" "release-1.0" "false" "1.0.2" "false" "true" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.2
}

@test "DEV_N edge regression suite" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/devn-edge"

  commit_msg "chore: initial commit"
  commit_msg "feat: 1"

  git checkout -q -b release-1.0
  assert_calc "E1" "release-1.0" "false" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.0

  assert_calc "E2" "release-1.0" "true" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development
  commit_msg "feat: 2"
  assert_calc "E3" "development" "false" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.1
  assert_calc "E4" "release-1.1" "false" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0-rc.0

  git checkout -q development
  commit_msg "fix: edge-after-rc-cut"
  assert_calc "E5" "development" "false" "1.2.0-dev.1" "false" "false" "false" "" "tag"
}
