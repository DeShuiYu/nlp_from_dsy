#!/bin/bash
# This script is meant to be called by the "script" step defined in
# .travis.yml. See https://docs.travis-ci.com/ for more details.
# The behavior of the script is controlled by environment variabled defined
# in the .travis.yml in the top level folder of the project.

# License: 3-clause BSD

set -e

python --version
python -c "import numpy; print('numpy %s' % numpy.__version__)"
python -c "import scipy; print('scipy %s' % scipy.__version__)"
python -c "\
try:
    import pandas
    print('pandas %s' % pandas.__version__)
except ImportError:
    pass
"
python -c "import joblib; print(joblib.cpu_count(), 'CPUs')"
python -c "import platform; print(platform.machine())"

if [[ "$BUILD_WITH_ICC" == "true" ]]; then
    # the tools in the oneAPI toolkits are configured via environment variables
    # which are also required at runtime.
    source /opt/intel/inteloneapi/setvars.sh
fi

run_tests() {
    TEST_CMD="pytest --showlocals --durations=20 --pyargs"

    # Get into a temp directory to run test from the installed scikit-learn and
    # check if we do not leave artifacts
    mkdir -p $TEST_DIR
    # We need the setup.cfg for the pytest settings
    cp setup.cfg $TEST_DIR
    cd $TEST_DIR

    if [[ "$TRAVIS_CPU_ARCH" == "arm64" ]]; then
        # use pytest-xdist for faster tests
        TEST_CMD="$TEST_CMD -n $CI_CPU_COUNT"
    else
        # Tests that require large downloads over the networks are skipped in CI.
        # Here we make sure, that they are still run on a regular basis.
        #
        # Note that using pytest-xdist is currently not compatible
        # with fetching datasets in tests due to datasets cache corruptions issues.
        export SKLEARN_SKIP_NETWORK_TESTS=0
    fi

    if [[ "$COVERAGE" == "true" ]]; then
        TEST_CMD="$TEST_CMD --cov sklearn"
    fi

    if [[ -n "$CHECK_WARNINGS" ]]; then
        TEST_CMD="$TEST_CMD -Werror::DeprecationWarning -Werror::FutureWarning"
    fi

    set -x  # print executed commands to the terminal

    $TEST_CMD sklearn
}

run_tests
