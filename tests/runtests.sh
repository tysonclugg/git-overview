#!/bin/bash
set -euo pipefail

# perform tests in the directory containing the script
cd "${0%/*}"

alias git-overview="../git-overview"

git --version

git-overview --version

fixtures=(
    "git clone https://github.com/octocat/Hello-World.git simple.test"
    "git clone https://github.com/octocat/Hello-World.git local-branch.test; cd local-branch.test; git switch -c local-branch"
    "git clone https://github.com/octocat/Hello-World.git repo.test; cd repo.test; git worktree add ../worktree.test test"
    "git clone https://github.com/octocat/Hello-World.git detached.test; cd detached.test; git checkout --detach HEAD"
    "git clone https://github.com/octocat/Hello-World.git detached2.test; cd detached2.test; git worktree add ../detached-worktree.test test; cd ../detached-worktree.test; git checkout --detach HEAD"
    "git clone --bare https://github.com/octocat/Hello-World.git bare.test"
    "git clone --mirror https://github.com/octocat/Hello-World.git mirror.test"
    "git clone --depth 1 https://github.com/octocat/Hello-World.git depth.test"
    "git clone --single-branch https://github.com/octocat/Hello-World.git single.test"
    "git clone https://github.com/octocat/Hello-World.git orphan.test; cd orphan.test; git switch --orphan orphaned-branch"
    "mkdir empty.test; cd empty.test; git init"
    "mkdir bare-empty.test; cd bare-empty.test; git init --bare"
)

tests=(
    "git-overview"
    "git-overview --all"
    "git-overview --list"
    "git-overview --shortstat"
    "git-overview --verbose"
    "git-overview --all --verbose --shortstat"
    "git-overview --for-each-worktree pwd"
)

failures=()

# remove cruft from previous failed test runs
rm -rf ./*.test
shopt -s nullglob

run_start=${EPOCHREALTIME/./}
fixtures_started=0
fixtures_errored=0
tests_started=0
tests_passed=0
tests_failed=0

for fixture in "${fixtures[@]}"
do
    printf "\u2501%.0s" {1..76}
    printf "\n"
    fixtures_started=$((fixtures_started + 1))
    fixture_start=${EPOCHREALTIME/./}
    if (
        eval "set -x; $fixture"
    )
    then
        fixture_stop=${EPOCHREALTIME/./}
        fixture_status=0
        for dir in ./*.test
        do
            printf "\u2500%.0s" {1..76}
            printf "\n%s\n" "$dir"
            for test in "${tests[@]}"
            do
                printf "\u2508%.0s" {1..76}
                printf "\n"
                tests_started=$((tests_started + 1))
                test_start=${EPOCHREALTIME/./}
                if (
                    cd "$dir"
                    set -x
                    $test
                )
                then
                    test_stop=${EPOCHREALTIME/./}
                    tests_passed=$((tests_passed + 1))
                    printf " %68.6fs OK \u2705\n" "$((test_stop - test_start))e-6"
                else
                    err=$?
                    test_stop=${EPOCHREALTIME/./}
                    tests_failed=$((tests_failed + 1))
                    printf "%73s \u274c\n" "$(printf "%.6fs FAIL[%d]" "$((test_stop - test_start))e-6" "$err")"
                    if [ $fixture_status -eq 0 ]
                    then
                        failures+=("( $fixture )")
                    fi
                    failures+=("  ( cd $dir; $test )")
                    fixture_status=$((fixture_status + 1))
                fi
            done
        done
    else
        err=$?
        fixture_stop=${EPOCHREALTIME/./}
        fixtures_errored=$((fixtures_errored + 1))
        printf "ERROR[%d] running fixture (%.6fs)" "$err" "$(( fixture_stop - fixture_start ))e-6"
        failures+=("( $fixture )")
    fi
    # clean up after successful test run
    rm -rf ./*.test
done

run_time=$((${EPOCHREALTIME/./} - run_start))

if [ ${#failures[@]} -gt 0 ]
then
    printf "\u2501%.0s" {1..76}
    printf "\n"
    printf "Failures:\n"
    printf "cd %s\n" "$(pwd)"
    for failure in "${failures[@]}"
    do
        printf "  %s\n" "$failure"
    done
fi

printf "\u2501%.0s" {1..76}
printf "\n\u231A %d tests ran in %.6fs\n" "$tests_started" "${run_time}e-6"

printf "\u2508%.0s" {1..76}
printf "\n"
printf "Fixtures:\n"
printf "  \U0001F197 Good:    %3d\n" "$((fixtures_started - fixtures_errored))"
[ "$fixtures_errored" -gt 0 ] && \
printf "  \U0001F198 Errored: %3d\n" "$fixtures_errored"

printf "\u2508%.0s" {1..76}
printf "\n"
printf "Tests:\n"
printf "  \u2705 Passed:  %3d\n" "$tests_passed"
[ "$tests_failed" -gt 0 ] && \
printf "  \u274c Failed:  %3d\n" "$tests_failed"

printf "\u2501%.0s" {1..76}
printf "\n"
if [ "$tests_started" -eq "$tests_passed" ]
then
    printf "\u2728 All done! \u2728\n"
else
    printf "\U0001F525 Oh no! \U0001F525\n"
fi
printf "\u2501%.0s" {1..76}
printf "\n"

exit $((tests_started - tests_passed + fixtures_errored))
