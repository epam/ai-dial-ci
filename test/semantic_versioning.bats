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
  local msg="${1}"
  COMMIT_COUNTER=$((COMMIT_COUNTER + 1))
  mkdir -p commits
  printf "%s\n" "${msg}" >"commits/${COMMIT_COUNTER}.txt"
  git add "commits/${COMMIT_COUNTER}.txt"
  git commit -q -m "${msg}"
  LAST_COMMIT_SHA=$(git rev-parse HEAD)
}

cherry_pick_commit() {
  local sha="${1}"
  git cherry-pick -x --no-edit "${sha}" >/dev/null
}

init_dummy_repo() {
  local repo_dir="${1}"
  mkdir -p "${repo_dir}"
  cd "${repo_dir}"
  git init -q --initial-branch=development
  git config user.name "dummy"
  git config user.email "dummy@example.com"

  # HACK: add a local remote so `git fetch --tags` inside the action doesn't fail
  git remote add origin "$(pwd)"
}

read_output_key() {
  local key="${1}"
  grep "^${key}=" "${BATS_TEST_TMPDIR}/calc_output.txt" | tail -1 | cut -d= -f2-
}

run_calc() {
  local filter_version="${1:-[0-9]+\.[0-9]+}"
  local promote="${2}"
  local primary_branch_pattern="${3:-^development$}"
  local release_branch_pattern="${4:-^release-[0-9]+\.[0-9]+$}"

  local GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/calc_output.txt"
  local GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/calc_summary.md"

  : >"${GITHUB_OUTPUT}"
  : >"${GITHUB_STEP_SUMMARY}"

  INPUT_FILTER_VERSION="${filter_version}" \
  INPUT_PROMOTE="${promote}" \
  INPUT_PRIMARY_BRANCH_PATTERN="${primary_branch_pattern}" \
  INPUT_RELEASE_BRANCH_PATTERN="${release_branch_pattern}" \
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
  local scenario="${1}"
  local branch="${2}"
  local filter_version="${3}"
  local promote="${4}"
  local primary_branch_pattern="${5}"
  local release_branch_pattern="${6}"
  local expected_next="${7}"
  local expected_is_rc="${8}"
  local expected_is_release="${9}"
  local expected_is_latest="${10}"
  local expected_release_line="${11}"
  local expected_changelog_mode="${12}"

  if [ "$#" -ne 12 ]; then
    echo "FAIL ${scenario}: Invalid assert_calc argument count '$#'" >&3
    return 1
  fi

  git checkout -q "${branch}"
  run_calc "${filter_version}" "${promote}" "${primary_branch_pattern}" "${release_branch_pattern}"

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

@test "DEV_N calculation" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/devn-calculation"

  local PRIMARY_PATTERN="^development$"
  local RELEASE_PATTERN="^release-[0-9]+\.[0-9]+$"
  local FILTER_VERSION="[0-9]+\.[0-9]+"

  commit_msg "chore: initial commit"
  commit_msg "feat: 1"

  git checkout -q -b release-1.0
  assert_calc "E1" "release-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.0

  assert_calc "E2" "release-1.0" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development
  commit_msg "feat: 2"
  assert_calc "E3" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.1
  assert_calc "E4" "release-1.1" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0-rc.0

  git checkout -q development
  commit_msg "fix: edge-after-rc-cut"
  assert_calc "E5" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-dev.1" "false" "false" "false" "" "tag"
}

@test "Custom branch patterns preserve current primary and release semantics" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/custom-branch-patterns"
  local FILTER_VERSION="[0-9]+\.[0-9]+"

  commit_msg "chore: initial commit"
  git checkout -q -b trunk

  run_calc "${FILTER_VERSION}" "false" "^trunk$" "^cut-[0-9]+\.[0-9]+$"
  [ "0.1.0-dev.1" = "${CALC_NEXT_VERSION}" ]
  [ "false" = "${CALC_IS_RELEASE_CANDIDATE}" ]
  [ "false" = "${CALC_IS_RELEASE}" ]
  [ "false" = "${CALC_IS_LATEST}" ]
  [ "" = "${CALC_RELEASE_LINE}" ]
  [ "tag" = "${CALC_CHANGELOG_MODE}" ]

  git checkout -q -b cut-1.0
  run_calc "${FILTER_VERSION}" "false" "^trunk$" "^cut-[0-9]+\.[0-9]+$"
  [ "1.0.0-rc.0" = "${CALC_NEXT_VERSION}" ]
  [ "true" = "${CALC_IS_RELEASE_CANDIDATE}" ]
  [ "false" = "${CALC_IS_RELEASE}" ]
  [ "false" = "${CALC_IS_LATEST}" ]
  [ "1.0" = "${CALC_RELEASE_LINE}" ]
  [ "tag" = "${CALC_CHANGELOG_MODE}" ]
}

@test "Invalid release-line capture" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/invalid-release-line-capture"

  commit_msg "chore: initial commit"
  git checkout -q -b rel-abc

  local GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/calc_output_invalid.txt"
  local GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/calc_summary_invalid.md"

  : >"${GITHUB_OUTPUT}"
  : >"${GITHUB_STEP_SUMMARY}"

  INPUT_PROMOTE="false" \
  INPUT_PRIMARY_BRANCH_PATTERN="^development$" \
  INPUT_RELEASE_BRANCH_PATTERN="^rel-.+$" \
  INPUT_FILTER_VERSION="[0-9]+\.[0-9]+" \
  GITHUB_OUTPUT="${GITHUB_OUTPUT}" \
  GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY}" \
  run bash "${ACTION_RUN_SCRIPT}"

  [ "$status" -eq 2 ]
  [[ "$output" == *"Expected branch name ending with X.Y"* ]]
}

@test "Full lifecycle simulation" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/full-lifecycle"

  local PRIMARY_PATTERN="^development$"
  local RELEASE_PATTERN="^release-[0-9]+\.[0-9]+$"
  local FILTER_VERSION="[0-9]+\.[0-9]+"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.0
  assert_calc "S2" "release-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.0

  git checkout -q development
  commit_msg "fix: 1"
  local sha_fix1="${LAST_COMMIT_SHA}"
  assert_calc "S3" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix1}"
  assert_calc "S4" "release-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.1" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.1

  assert_calc "S5" "release-1.0" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development
  commit_msg "feat: 2"
  commit_msg "fix: 2"
  local sha_fix2="${LAST_COMMIT_SHA}"
  assert_calc "S6" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix2}"
  assert_calc "S7" "release-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.1" "false" "true" "true" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.1

  git checkout -q development
  git checkout -q -b release-1.1
  assert_calc "S8" "release-1.1" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0-rc.0

  assert_calc "S9" "release-1.1" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0" "false" "true" "true" "1.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0

  git checkout -q development
  commit_msg "feat: 3"
  assert_calc "S10" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.2
  assert_calc "S11" "release-1.2" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-rc.0" "true" "false" "false" "1.2" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0-rc.0

  assert_calc "S12" "release-1.2" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0" "false" "true" "true" "1.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0

  git checkout -q development
  commit_msg "fix: 3"
  local sha_fix3="${LAST_COMMIT_SHA}"
  commit_msg "fix: 4"
  local sha_fix4="${LAST_COMMIT_SHA}"
  commit_msg "fix: 5"
  local sha_fix5="${LAST_COMMIT_SHA}"
  assert_calc "S13" "development" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.3.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q release-1.1
  cherry_pick_commit "${sha_fix3}"
  assert_calc "S14" "release-1.1" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.1" "false" "true" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.1

  git checkout -q release-1.2
  cherry_pick_commit "${sha_fix4}"
  assert_calc "S15" "release-1.2" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.1" "false" "true" "true" "1.2" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.2.1

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix5}"
  assert_calc "S16" "release-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.2" "false" "true" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.2
}

@test "Full lifecycle simulation with custom branch names" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/full-lifecycle-custom-branches"

  local PRIMARY_PATTERN="^trunk$"
  local RELEASE_PATTERN="^cut-[0-9]+\.[0-9]+$"
  local FILTER_VERSION="[0-9]+\.[0-9]+"

  git checkout -q -b trunk

  commit_msg "chore: initial commit"
  assert_calc "CS0" "trunk" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "CS1" "trunk" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b cut-1.0
  assert_calc "CS2" "cut-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.0

  git checkout -q trunk
  commit_msg "fix: 1"
  local sha_fix1="${LAST_COMMIT_SHA}"
  assert_calc "CS3" "trunk" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q cut-1.0
  cherry_pick_commit "${sha_fix1}"
  assert_calc "CS4" "cut-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.1" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.1

  assert_calc "CS5" "cut-1.0" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q trunk
  commit_msg "feat: 2"
  commit_msg "fix: 2"
  local sha_fix2="${LAST_COMMIT_SHA}"
  assert_calc "CS6" "trunk" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q cut-1.0
  cherry_pick_commit "${sha_fix2}"
  assert_calc "CS7" "cut-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.1" "false" "true" "true" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.1

  git checkout -q trunk
  git checkout -q -b cut-1.1
  assert_calc "CS8" "cut-1.1" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0-rc.0

  assert_calc "CS9" "cut-1.1" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0" "false" "true" "true" "1.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0

  git checkout -q trunk
  commit_msg "feat: 3"
  assert_calc "CS10" "trunk" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b cut-1.2
  assert_calc "CS11" "cut-1.2" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-rc.0" "true" "false" "false" "1.2" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0-rc.0

  assert_calc "CS12" "cut-1.2" "${FILTER_VERSION}" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0" "false" "true" "true" "1.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0

  git checkout -q trunk
  commit_msg "fix: 3"
  local sha_fix3="${LAST_COMMIT_SHA}"
  commit_msg "fix: 4"
  local sha_fix4="${LAST_COMMIT_SHA}"
  commit_msg "fix: 5"
  local sha_fix5="${LAST_COMMIT_SHA}"
  assert_calc "CS13" "trunk" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.3.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q cut-1.1
  cherry_pick_commit "${sha_fix3}"
  assert_calc "CS14" "cut-1.1" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.1" "false" "true" "false" "1.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.1.1

  git checkout -q cut-1.2
  cherry_pick_commit "${sha_fix4}"
  assert_calc "CS15" "cut-1.2" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.1" "false" "true" "true" "1.2" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.2.1

  git checkout -q cut-1.0
  cherry_pick_commit "${sha_fix5}"
  assert_calc "CS16" "cut-1.0" "${FILTER_VERSION}" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.2" "false" "true" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.2
}

@test "Two development branches simultaneously" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/two-dev-branches"

  local PRIMARY_PATTERN="^development$|^development-.+$"
  local RELEASE_PATTERN="^release-[0-9]+\.[0-9]+$"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.1
  assert_calc "S2" "release-0.1" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-rc.0" "true" "false" "false" "0.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0-rc.0

  git checkout -q development
  commit_msg "fix: 1"
  sha_fix1="${LAST_COMMIT_SHA}"
  assert_calc "S3" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-0.1
  cherry_pick_commit "${sha_fix1}"
  assert_calc "S4" "release-0.1" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-rc.1" "true" "false" "false" "0.1" "tag"

  assert_calc "S5" "release-0.1" "" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0" "false" "true" "true" "0.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0

  git checkout -q development
  commit_msg "feat: 2"
  assert_calc "S6" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.2
  assert_calc "S7" "release-0.2" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0-rc.0" "true" "false" "false" "0.2" "tag"

  assert_calc "S8" "release-0.2" "" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0" "false" "true" "true" "0.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.2.0

  git checkout -q development
  commit_msg "fix: 2"
  sha_fix2="${LAST_COMMIT_SHA}"
  assert_calc "S9" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-0.2
  cherry_pick_commit "${sha_fix2}"
  assert_calc "S10" "release-0.2" "" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.1" "false" "true" "true" "0.2" "tag"
  git tag 0.2.1

  git checkout -q development
  commit_msg "feat: 3"
  assert_calc "S11" "development" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b development-1.0
  commit_msg "feat: 4"
  assert_calc "S12" "development-1.0" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q development
  commit_msg "feat: 5"
  commit_msg "feat: 6"
  commit_msg "feat: 7"
  assert_calc "S13" "development" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-dev.5" "false" "false" "false" "" "tag"

  git checkout -q development-1.0
  commit_msg "feat: 8"
  assert_calc "S14" "development-1.0" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-dev.4" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.0
  assert_calc "S15" "release-1.0" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  git tag 1.0.0-rc.0

  assert_calc "S16" "release-1.0" "1\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development
  git checkout -q -b release-0.3
  assert_calc "S17" "release-0.3" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-rc.0" "true" "false" "false" "0.3" "tag"
  git tag 0.3.0-rc.0

  git checkout -q development
  commit_msg "fix: 7"
  sha_fix7="${LAST_COMMIT_SHA}"
  assert_calc "S18" "development" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.4.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-0.3
  cherry_pick_commit "${sha_fix7}"
  assert_calc "S19" "release-0.3" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-rc.1" "true" "false" "false" "0.3" "tag"
  git tag 0.3.0-rc.1

  assert_calc "S20" "release-0.3" "0\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0" "false" "true" "false" "0.3" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.3.0

  git checkout -q development-1.0
  commit_msg "fix: 8"
  sha_fix8="${LAST_COMMIT_SHA}"
  commit_msg "feat: 9"
  assert_calc "S21" "development-1.0" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.1
  assert_calc "S22" "release-1.1" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  git tag 1.1.0-rc.0

  assert_calc "S23" "release-1.1" "1\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0" "false" "true" "true" "1.1" "merge-base"
  git tag 1.1.0

  git checkout -q development-1.0
  commit_msg "fix: 9"
  sha_fix9="${LAST_COMMIT_SHA}"
  assert_calc "S24" "development-1.0" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix9}"
  assert_calc "S25" "release-1.0" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.1" "false" "true" "false" "1.0" "tag"
  git tag 1.0.1

  git checkout -q release-1.1
  cherry_pick_commit "${sha_fix9}"
  assert_calc "S26" "release-1.1" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.1" "false" "true" "true" "1.1" "tag"
  git tag 1.1.1

  git checkout -q development-1.0
  commit_msg "feat: 10"
  commit_msg "feat: 11"
  assert_calc "S27" "development-1.0" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q development
  commit_msg "feat: 12"
  assert_calc "S28" "development" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.4.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.4
  assert_calc "S29" "release-0.4" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.4.0-rc.0" "true" "false" "false" "0.4" "tag"
  git tag 0.4.0-rc.0

  assert_calc "S30" "release-0.4" "0\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.4.0" "false" "true" "false" "0.4" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.4.0

  git checkout -q development-1.0
  commit_msg "feat: 13"
  commit_msg "fix: 11"
  sha_fix11="${LAST_COMMIT_SHA}"
  assert_calc "S31" "development-1.0" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-dev.5" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.2
  assert_calc "S32" "release-1.2" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0-rc.0" "true" "false" "false" "1.2" "tag"
  git tag 1.2.0-rc.0

  git checkout -q release-1.2
  assert_calc "S33" "release-1.2" "1\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.2.0" "false" "true" "true" "1.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.2.0
}

@test "Swap development branches" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/swap-dev-branches"

  local PRIMARY_PATTERN="^development$|^development-.+$"
  local RELEASE_PATTERN="^release-[0-9]+\.[0-9]+$"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.1
  assert_calc "S2" "release-0.1" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0-rc.0" "true" "false" "false" "0.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0-rc.0

  assert_calc "S3" "release-0.1" "" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.1.0" "false" "true" "true" "0.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0

  git checkout -q development
  commit_msg "ci: filter 0.x versions"
  assert_calc "S4" "development" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b development-1.x
  commit_msg "feat: 3"
  assert_calc "S5" "development-1.x" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.0
  assert_calc "S6" "release-1.0" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  git tag 1.0.0-rc.0

  assert_calc "S7" "release-1.0" "1\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development
  git checkout -q -b release-0.2
  assert_calc "S8" "release-0.2" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0-rc.0" "true" "false" "false" "0.2" "tag"
  git tag 0.2.0-rc.0

  assert_calc "S9" "release-0.2" "0\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.2.0" "false" "true" "false" "0.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.2.0

  git branch -q -m development development-0.x
  git branch -q -m development-1.x development
  git checkout -q development
  commit_msg "feat: 4"
  assert_calc "S10" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q development-0.x
  commit_msg "feat: 5"
  assert_calc "S11" "development-0.x" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.3
  assert_calc "S12" "release-0.3" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-rc.0" "true" "false" "false" "0.3" "tag"
  git tag 0.3.0-rc.0

  git checkout -q development-0.x
  commit_msg "fix: 5"
  sha_fix5="${LAST_COMMIT_SHA}"
  assert_calc "S13" "development-0.x" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.4.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-0.3
  cherry_pick_commit "${sha_fix5}"
  assert_calc "S14" "release-0.3" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0-rc.1" "true" "false" "false" "0.3" "tag"
  git tag 0.3.0-rc.1

  assert_calc "S15" "release-0.3" "0\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.0" "false" "true" "false" "0.3" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.3.0

  git checkout -q development-0.x
  commit_msg "fix: 6"
  sha_fix6="${LAST_COMMIT_SHA}"
  assert_calc "S19" "development-0.x" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.4.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q release-0.3
  cherry_pick_commit "${sha_fix6}"
  assert_calc "S20" "release-0.3" "0\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "0.3.1" "false" "true" "false" "0.3" "tag"
  git tag 0.3.1

  git checkout -q development
  commit_msg "feat: 7"
  commit_msg "feat: 8"
  assert_calc "S21" "development" "" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.1
  assert_calc "S22" "release-1.1" "1\.[0-9]+" "false" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0-rc.0" "true" "false" "false" "1.1" "tag"
  git tag 1.1.0-rc.0

  assert_calc "S23" "release-1.1" "1\.[0-9]+" "true" "${PRIMARY_PATTERN}" "${RELEASE_PATTERN}" "1.1.0" "false" "true" "true" "1.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.1.0
}

@test "Default version filter" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/default-version-filter"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "" "false" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "" "false" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.1
  assert_calc "S2" "release-0.1" "" "false" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0-rc.0" "true" "false" "false" "0.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0-rc.0

  assert_calc "S3" "release-0.1" "" "true" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0" "false" "true" "true" "0.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0

  git checkout -q development
  commit_msg "ci: filter 0.x versions"
  assert_calc "S4" "development" "0\.[0-9]+" "false" "^development$" "^release-0\.[0-9]+$" "0.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b development-1.x
  commit_msg "feat: 3"
  assert_calc "S5" "development-1.x" "" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0-dev.2" "false" "false" "false" "" "tag"

  commit_msg "feat: 4"
  assert_calc "S6" "development-1.x" "" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.0
  assert_calc "S7" "release-1.0" "" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  git tag 1.0.0-rc.0

  git checkout -q development-1.x
  commit_msg "fix: 4"
  local sha_fix4="${LAST_COMMIT_SHA}"
  assert_calc "S8" "development-1.x" "" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix4}"
  assert_calc "S9" "release-1.0" "" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0-rc.1" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.1

  assert_calc "S10" "release-1.0" "" "true" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0
}

@test "Strict version filter" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/strict-version-filter"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "" "false" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "" "false" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.1
  assert_calc "S2" "release-0.1" "" "false" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0-rc.0" "true" "false" "false" "0.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0-rc.0

  assert_calc "S3" "release-0.1" "" "true" "^development$" "^release-[0-9]+\.[0-9]+$" "0.1.0" "false" "true" "true" "0.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0

  git checkout -q development
  commit_msg "ci: filter 0.x versions"
  assert_calc "S4" "development" "0\.[0-9]+" "false" "^development$" "^release-0\.[0-9]+$" "0.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q -b development-1.x
  commit_msg "feat: 3"
  assert_calc "S5" "development-1.x" "1\.[0-9]+" "false" "^development-1\.x$" "^release-1\.[0-9]+$" "1.0.0-dev.2" "false" "false" "false" "" "tag"

  commit_msg "feat: 4"
  assert_calc "S6" "development-1.x" "1\.[0-9]+" "false" "^development-1\.x$" "^release-1\.[0-9]+$" "1.0.0-dev.3" "false" "false" "false" "" "tag"

  git checkout -q -b release-1.0
  assert_calc "S7" "release-1.0" "1\.[0-9]+" "false" "^development-1\.x$" "^release-1\.[0-9]+$" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  git tag 1.0.0-rc.0

  git checkout -q development-1.x
  commit_msg "fix: 4"
  local sha_fix4="${LAST_COMMIT_SHA}"
  assert_calc "S8" "development-1.x" "1\.[0-9]+" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.1.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_fix4}"
  assert_calc "S9" "release-1.0" "1\.[0-9]+" "false" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0-rc.1" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.1

  assert_calc "S10" "release-1.0" "1\.[0-9]+" "true" "^development-1\.x$" "^release-[0-9]+\.[0-9]+$" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0
}

@test "Bump major version using long RC" {
  init_dummy_repo "${BATS_TEST_TMPDIR}/bump-major-version-using-long-rc"

  commit_msg "chore: initial commit"
  assert_calc "S0" "development" "" "false" "^development$" "^release-[0-9]\.[0-9]+" "0.1.0-dev.1" "false" "false" "false" "" "tag"

  commit_msg "feat: 1"
  assert_calc "S1" "development" "" "false" "^development$" "^release-[0-9]\.[0-9]+" "0.1.0-dev.2" "false" "false" "false" "" "tag"

  git checkout -q -b release-0.1
  assert_calc "S2" "release-0.1" "" "false" "^development$" "^release-[0-9]\.[0-9]+" "0.1.0-rc.0" "true" "false" "false" "0.1" "tag"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0-rc.0

  assert_calc "S3" "release-0.1" "" "true" "^development$" "^release-[0-9]\.[0-9]+" "0.1.0" "false" "true" "true" "0.1" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.1.0

  git checkout -q development
  git checkout -q -b development-0.x
  commit_msg "ci: legacy 0.x versions"
  assert_calc "S4" "development-0.x" "0\.[0-9]+" "false" "^development-0\.x$" "^release-0\.[0-9]+" "0.2.0-dev.1" "false" "false" "false" "" "tag"

  git checkout -q development
  git checkout -q -b release-1.0
  assert_calc "S5" "release-1.0" "" "false" "^development$" "^release-[0-9]+\.[0-9]+" "1.0.0-rc.0" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.0

  git checkout -q development
  commit_msg "feat: 2"
  local sha_feat2="${LAST_COMMIT_SHA}"
  commit_msg "feat: 3"
  local sha_feat3="${LAST_COMMIT_SHA}"
  commit_msg "feat: 4"
  local sha_feat4="${LAST_COMMIT_SHA}"
  commit_msg "feat: 5"
  local sha_feat5="${LAST_COMMIT_SHA}"
  assert_calc "S6" "development" "" "false" "^development$" "^release-[0-9]+\.[0-9]+" "1.1.0-dev.4" "false" "false" "false" "" "tag"

  git checkout -q release-1.0
  cherry_pick_commit "${sha_feat2}"
  cherry_pick_commit "${sha_feat3}"
  cherry_pick_commit "${sha_feat4}"
  cherry_pick_commit "${sha_feat5}"
  assert_calc "S7" "release-1.0" "" "false" "^development$" "^release-[0-9]+\.[0-9]+" "1.0.0-rc.1" "true" "false" "false" "1.0" "tag"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0-rc.1

  assert_calc "S8" "release-1.0" "" "true" "^development$" "^release-[0-9]+\.[0-9]+" "1.0.0" "false" "true" "true" "1.0" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 1.0.0

  git checkout -q development-0.x
  git checkout -q -b release-0.2
  assert_calc "S9" "release-0.2" "0\.[0-9]+" "false" "^development-0\.x$" "^release-0\.[0-9]+" "0.2.0-rc.0" "true" "false" "false" "0.2" "tag"
  git tag 0.2.0-rc.0

  assert_calc "S10" "release-0.2" "0\.[0-9]+" "true" "^development-0\.x$" "^release-0\.[0-9]+" "0.2.0" "false" "true" "false" "0.2" "merge-base"
  commit_msg "[skip ci] Update version"
  git tag 0.2.0

  git checkout -q development
  commit_msg "feat: 6"
  assert_calc "S11" "development" "" "false" "^development$" "^release-[0-9]+\.[0-9]+" "1.1.0-dev.5" "false" "false" "false" "" "tag"
}
